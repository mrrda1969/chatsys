import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? currentCallId;

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
  };

  final Map<String, dynamic> offerSdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  Future<void> initializeCall(String callId) async {
    currentCallId = callId;
    await _createPeerConnection();
  }

  Future<void> _createPeerConnection() async {
    peerConnection = await createPeerConnection(configuration);

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _addIceCandidate(candidate);
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      remoteStream = stream;
    };

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
      },
    });

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });
  }

  Future<void> createOffer(String calleeId) async {
    try {
      RTCSessionDescription description =
          await peerConnection!.createOffer(offerSdpConstraints);
      await peerConnection!.setLocalDescription(description);

      await _firestore.collection('calls').doc(currentCallId).set({
        'caller': _auth.currentUser!.uid,
        'callee': calleeId,
        'offer': description.toMap(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating offer: $e');
    }
  }

  Future<void> handleOffer(RTCSessionDescription offer) async {
    try {
      await peerConnection!.setRemoteDescription(offer);
      RTCSessionDescription answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);

      await _firestore.collection('calls').doc(currentCallId).update({
        'answer': answer.toMap(),
        'status': 'connected',
      });
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  Future<void> handleAnswer(RTCSessionDescription answer) async {
    try {
      await peerConnection!.setRemoteDescription(answer);
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  Future<void> _addIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _firestore
          .collection('calls')
          .doc(currentCallId)
          .collection('candidates')
          .add({
        'candidate': candidate.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  Future<void> handleRemoteCandidate(Map<String, dynamic> candidateData) async {
    try {
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      await peerConnection?.addCandidate(candidate);
    } catch (e) {
      print('Error handling remote candidate: $e');
    }
  }

  Future<void> endCall() async {
    try {
      await localStream?.dispose();
      await remoteStream?.dispose();
      await peerConnection?.close();

      if (currentCallId != null) {
        await _firestore.collection('calls').doc(currentCallId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error ending call: $e');
    } finally {
      localStream = null;
      remoteStream = null;
      peerConnection = null;
      currentCallId = null;
    }
  }
}
