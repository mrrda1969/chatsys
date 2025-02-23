import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoChatPage extends StatefulWidget {
  final String peerId;
  final bool isIncomingCall;
  final String? callId;

  const VideoChatPage({
    super.key,
    required this.peerId,
    this.isIncomingCall = false,
    this.callId,
  });

  @override
  _VideoChatPageState createState() => _VideoChatPageState();
}

class _VideoChatPageState extends State<VideoChatPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  late RTCPeerConnection _peerConnection;
  MediaStream? _localStream;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isCallConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _startVideoCall();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _startVideoCall() async {
    try {
      // Create peer connection
      _peerConnection = await _createPeerConnection();

      // Get local media stream
      _localStream = await _getUserMedia();

      // Add local stream to renderer
      _localRenderer.srcObject = _localStream;

      // Add local tracks to peer connection
      _localStream?.getTracks().forEach((track) {
        _peerConnection.addTrack(track, _localStream!);
      });

      if (widget.isIncomingCall && widget.callId != null) {
        await _handleIncomingCall();
      } else {
        await _initiateOutgoingCall();
      }
    } catch (e) {
      print('Error starting video call: $e');
      _showErrorDialog('Failed to start video call');
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
          ],
        },
      ],
    };

    final peerConnection = await createPeerConnection(configuration);

    peerConnection.onTrack = (event) {
      if (event.track != null) {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {
          _isCallConnected = true;
        });
      }
    };

    peerConnection.onIceCandidate = (candidate) {
      if (candidate != null) {
        _sendIceCandidate(candidate);
      }
    };

    return peerConnection;
  }

  Future<MediaStream> _getUserMedia() async {
    final mediaConstraints = {'video': true, 'audio': true};

    return await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  Future<void> _initiateOutgoingCall() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Create a new call document
    final callDoc = _firestore.collection('calls').doc();

    // Create offer
    final offer = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(offer);

    // Save call details
    await callDoc.set({
      'offer': offer.toMap(),
      'caller': currentUser.uid,
      'callee': widget.peerId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Listen for answer
    callDoc.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data.containsKey('answer')) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        _handleRemoteAnswer(answer);
      }
    });
  }

  Future<void> _handleIncomingCall() async {
    if (widget.callId == null) return;

    final callDoc =
        await _firestore.collection('calls').doc(widget.callId).get();
    final offerData = callDoc.data()?['offer'];

    if (offerData != null) {
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);

      // Set remote description
      await _peerConnection.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection.createAnswer();
      await _peerConnection.setLocalDescription(answer);

      // Update call document with answer
      await _firestore.collection('calls').doc(widget.callId).update({
        'answer': answer.toMap(),
        'status': 'accepted',
      });
    }
  }

  void _sendIceCandidate(RTCIceCandidate candidate) {
    // Implement ICE candidate exchange logic
    _firestore
        .collection('calls')
        .doc(widget.callId)
        .collection('candidates')
        .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
  }

  void _handleRemoteAnswer(RTCSessionDescription answer) async {
    await _peerConnection.setRemoteDescription(answer);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _endCall() {
    _localStream?.dispose();
    _remoteRenderer.dispose();
    _localRenderer.dispose();
    _peerConnection.close();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCallConnected ? 'Video Call' : 'Connecting...'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Remote video
                RTCVideoView(_remoteRenderer, mirror: false),

                // Local video (small overlay)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: SizedBox(
                    width: 120,
                    height: 160,
                    child: RTCVideoView(_localRenderer, mirror: true),
                  ),
                ),
              ],
            ),
          ),

          // Call controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.red),
                  iconSize: 50,
                  onPressed: _endCall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localStream?.dispose();
    _remoteRenderer.dispose();
    _localRenderer.dispose();
    _peerConnection.close();
    super.dispose();
  }
}

// Global function to navigate to video chat
void navigateToVideoChat(BuildContext context, String peerId) {
  // Check if user is authenticated before navigating
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => VideoChatPage(peerId: peerId, isIncomingCall: false),
      ),
    );
  } else {
    // Redirect to login if not authenticated
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in to start a video call')),
    );
  }
}
