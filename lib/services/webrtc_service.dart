import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebRTCService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Function(MediaStream)? onLocalStreamAvailable;
  Function(MediaStream)? onRemoteStreamAvailable;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  Future<String?> startCall(String recipientId) async {
    try {
      final callDoc = _firestore.collection('calls').doc();
      final callerId = _auth.currentUser?.uid;

      if (callerId == null) throw Exception('User not authenticated');

      await _initializePeerConnection();
      await _createLocalStream();

      final offer = await _peerConnection!.createOffer(_constraints);
      await _peerConnection!.setLocalDescription(offer);

      await callDoc.set({
        'callerId': callerId,
        'calleeId': recipientId,
        'offer': offer.toMap(),
        'status': 'calling',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Listen for answer
      callDoc.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data()!;

        if (data['status'] == 'answered' && data['answer'] != null) {
          final answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          await _peerConnection!.setRemoteDescription(answer);
        }
      });

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (candidate) async {
        await callDoc.collection('callerCandidates').add(candidate.toMap());
      };

      return callDoc.id;
    } catch (e) {
      print('Error starting call: $e');
      cleanup();
      return null;
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      final callDoc = _firestore.collection('calls').doc(callId);

      await _initializePeerConnection();
      await _createLocalStream();

      // Get the offer
      final callData = (await callDoc.get()).data();
      if (callData == null) throw Exception('Call data not found');

      final offer = RTCSessionDescription(
        callData['offer']['sdp'],
        callData['offer']['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);
      final answer = await _peerConnection!.createAnswer(_constraints);
      await _peerConnection!.setLocalDescription(answer);

      await callDoc.update({
        'answer': answer.toMap(),
        'status': 'answered',
      });

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (candidate) async {
        await callDoc.collection('calleeCandidates').add(candidate.toMap());
      };

      // Add caller ICE candidates
      callDoc.collection('callerCandidates').snapshots().listen((snapshot) {
        snapshot.docChanges.forEach((change) {
          if (change.type == DocumentChangeType.added) {
            final candidate = RTCIceCandidate(
              change.doc.data()!['candidate'],
              change.doc.data()!['sdpMid'],
              change.doc.data()!['sdpMLineIndex'],
            );
            _peerConnection!.addCandidate(candidate);
          }
        });
      });
    } catch (e) {
      print('Error answering call: $e');
      cleanup();
    }
  }

  Future<void> rejectCall(String callId, String userId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'rejectedBy': userId,
        'endedAt': FieldValue.serverTimestamp(),
      });
      cleanup();
    } catch (e) {
      print('Error rejecting call: $e');
    }
  }

  Future<void> _initializePeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        onRemoteStreamAvailable?.call(event.streams[0]);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      print('Connection state: $state');
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('ICE Connection state: $state');
    };
  }

  Future<void> _createLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStreamAvailable?.call(_localStream!);

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  List<MediaStreamTrack>? getLocalVideoTracks() {
    return _localStream?.getVideoTracks();
  }

  List<MediaStreamTrack>? getLocalAudioTracks() {
    return _localStream?.getAudioTracks();
  }

  Future<void> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
      });
      cleanup();
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  void cleanup() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}
