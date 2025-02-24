import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebRTCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Stream callback functions
  Function(MediaStream)? onLocalStreamAvailable;
  Function(MediaStream)? onRemoteStreamAvailable;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': {'facingMode': 'user'},
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

    // Trigger local stream callback if set
    onLocalStreamAvailable?.call(stream);

    return stream;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    RTCPeerConnection pc = await createPeerConnection(_configuration);

    _localStream = await _getUserMedia();
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Set up remote stream tracking
    pc.onTrack = (event) {
      if (event.track.kind == 'video') {
        _remoteStream = event.streams[0];
        onRemoteStreamAvailable?.call(_remoteStream!);
      }
    };

    return pc;
  }

  Future<void> startCall(String peerId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Create a new call document
    final callDoc = _firestore.collection('calls').doc();
    final callId = callDoc.id;

    try {
      _peerConnection = await _createPeerConnection();

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _firestore
            .collection('calls')
            .doc(callId)
            .collection('candidates')
            .add(candidate.toMap());
      };

      // Create and set local description
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Save the offer to Firestore
      await callDoc.set({
        'offer': offer.toMap(),
        'caller': currentUser.uid,
        'callee': peerId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Send push notification to the callee
      await _sendCallNotification(
        peerId,
        callId,
        currentUser.displayName ?? 'Someone',
      );

      // Listen for remote answer
      callDoc.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'answered' && data['answer'] != null) {
          final answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          await _peerConnection!.setRemoteDescription(answer);
        }
      });

      // Listen for ICE candidates from remote peer
      callDoc.collection('candidates').snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final candidate = RTCIceCandidate(
              change.doc.data()!['candidate'],
              change.doc.data()!['sdpMid'],
              change.doc.data()!['sdpMLineIndex'],
            );
            _peerConnection!.addCandidate(candidate);
          }
        }
      });
    } catch (e) {
      print('Error starting call: $e');
      cleanup();
    }
  }

  // Send call notification to the callee
  Future<void> _sendCallNotification(
    String calleeId,
    String callId,
    String callerName,
  ) async {
    try {
      // Store call notification in Firestore for the callee
      await _firestore
          .collection('users')
          .doc(calleeId)
          .collection('call_notifications')
          .doc(callId)
          .set({
            'callId': callId,
            'caller': _auth.currentUser?.uid,
            'callerName': callerName,
            'status': 'incoming',
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Optional: Add a listener for call notifications
      _firestore
          .collection('users')
          .doc(calleeId)
          .collection('call_notifications')
          .doc(callId)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data?['status'] == 'rejected') {
                // Handle call rejection
                cleanup();
              }
            }
          });
    } catch (e) {
      print('Error sending call notification: $e');
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      final callDoc = _firestore.collection('calls').doc(callId);
      final callData = (await callDoc.get()).data();

      if (callData == null) return;

      _peerConnection = await _createPeerConnection();

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        callDoc.collection('candidates').add(candidate.toMap());
      };

      // Set remote description (offer)
      final offer = RTCSessionDescription(
        callData['offer']['sdp'],
        callData['offer']['type'],
      );
      await _peerConnection!.setRemoteDescription(offer);

      // Create and set local description (answer)
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Save the answer to Firestore
      await callDoc.update({'answer': answer.toMap(), 'status': 'answered'});

      // Update call notification status
      await _firestore
          .collection('users')
          .doc(callData['caller'])
          .collection('call_notifications')
          .doc(callId)
          .update({'status': 'answered'});

      // Listen for ICE candidates from caller
      callDoc.collection('candidates').snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final candidate = RTCIceCandidate(
              change.doc.data()!['candidate'],
              change.doc.data()!['sdpMid'],
              change.doc.data()!['sdpMLineIndex'],
            );
            _peerConnection!.addCandidate(candidate);
          }
        }
      });
    } catch (e) {
      print('Error answering call: $e');
      cleanup();
    }
  }

  // Method to reject an incoming call
  Future<void> rejectCall(String callId, String callerId) async {
    try {
      // Update call document status
      final callDoc = _firestore.collection('calls').doc(callId);
      await callDoc.update({'status': 'rejected'});

      // Update call notification status
      await _firestore
          .collection('users')
          .doc(callerId)
          .collection('call_notifications')
          .doc(callId)
          .update({'status': 'rejected'});

      cleanup();
    } catch (e) {
      print('Error rejecting call: $e');
    }
  }

  void cleanup() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.getTracks().forEach((track) => track.stop());

    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
  }

  Future<void> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
      cleanup();
    } catch (e) {
      print('Error ending call: $e');
    }
  }
}
