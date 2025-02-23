import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class WebRTCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<RTCPeerConnection> createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {
          'urls': ['stun:stun.l.google.com:19302'],
        },
      ],
      'sdpSemantics': 'unified-plan',
    };

    RTCPeerConnection peerConnection = await createPeerConnection();

    return peerConnection;
  }

  Future<void> startCall(String peerId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final callDoc = _firestore.collection('calls').doc();
    final peerConnection = await createPeerConnection();

    final localStream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });

    localStream.getTracks().forEach((track) {
      peerConnection.addTrack(track, localStream);
    });

    final offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);

    await callDoc.set({
      'offer': offer.toMap(),
      'caller': currentUser.uid,
      'callee': peerId,
      'status': 'pending',
    });
  }

  Future<void> answerCall(String callId) async {
    final callDoc = await _firestore.collection('calls').doc(callId).get();
    if (!callDoc.exists) return;

    final offerData = callDoc.data()?['offer'];
    final RTCSessionDescription offer = RTCSessionDescription(
      offerData['sdp'],
      offerData['type'],
    );

    final peerConnection = await createPeerConnection();

    final localStream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });

    localStream.getTracks().forEach((track) {
      peerConnection.addTrack(track, localStream);
    });

    await peerConnection.setRemoteDescription(offer);

    final answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);

    await _firestore.collection('calls').doc(callId).update({
      'answer': answer.toMap(),
      'status': 'accepted',
    });
  }
}
