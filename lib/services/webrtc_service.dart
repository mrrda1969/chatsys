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
    onLocalStreamAvailable?.call(stream);
    return stream;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    RTCPeerConnection pc = await createPeerConnection(_configuration);

    _localStream = await _getUserMedia();
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

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
        'callerName': currentUser.displayName ?? currentUser.email ?? 'Unknown',
        'callee': peerId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'video',
      });

      // Create a notification document for the callee
      await _firestore
          .collection('users')
          .doc(peerId)
          .collection('notifications')
          .doc(callId)
          .set({
            'type': 'call',
            'callId': callId,
            'caller': currentUser.uid,
            'callerName':
                currentUser.displayName ?? currentUser.email ?? 'Unknown',
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
            'read': false,
          });

      // Listen for answer
      callDoc.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'answered' && data['answer'] != null) {
          final answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          await _peerConnection!.setRemoteDescription(answer);
        } else if (data['status'] == 'rejected' || data['status'] == 'ended') {
          cleanup();
        }
      });

      // Listen for ICE candidates
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
      rethrow;
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

      // Update notification status
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .doc(callId)
            .update({'status': 'answered', 'read': true});
      }

      // Listen for ICE candidates
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

      // Listen for call status changes
      callDoc.snapshots().listen((snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'ended') {
          cleanup();
        }
      });
    } catch (e) {
      print('Error answering call: $e');
      cleanup();
      rethrow;
    }
  }

  Future<void> rejectCall(String callId, String callerId) async {
    try {
      // Update call document status
      final callDoc = _firestore.collection('calls').doc(callId);
      await callDoc.update({'status': 'rejected'});

      // Update notification status
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .doc(callId)
            .update({'status': 'rejected', 'read': true});
      }

      cleanup();
    } catch (e) {
      print('Error rejecting call: $e');
      rethrow;
    }
  }

  Future<void> endCall(String callId) async {
    try {
      final callDoc = _firestore.collection('calls').doc(callId);
      final callData = (await callDoc.get()).data();

      if (callData != null) {
        // Update call status
        await callDoc.update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });

        // Update notification for both users
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // Update notification for caller
          await _firestore
              .collection('users')
              .doc(callData['caller'])
              .collection('notifications')
              .doc(callId)
              .update({'status': 'ended', 'read': true});

          // Update notification for callee
          await _firestore
              .collection('users')
              .doc(callData['callee'])
              .collection('notifications')
              .doc(callId)
              .update({'status': 'ended', 'read': true});
        }
      }

      cleanup();
    } catch (e) {
      print('Error ending call: $e');
      rethrow;
    }
  }

  void cleanup() {
    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      _remoteStream?.getTracks().forEach((track) => track.stop());

      _localStream?.dispose();
      _remoteStream?.dispose();
      _peerConnection?.close();

      _localStream = null;
      _remoteStream = null;
      _peerConnection = null;
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }
}
