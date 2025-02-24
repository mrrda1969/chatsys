import 'package:chatsys/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String remoteUserId;
  final bool isIncoming;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.remoteUserId,
    required this.isIncoming,
  });

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isCallConnected = false;
  bool _isMicMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    await _callService.initializeCall(widget.callId);

    if (_callService.localStream != null) {
      _localRenderer.srcObject = _callService.localStream;
    }

    if (!widget.isIncoming) {
      await _callService.createOffer(widget.remoteUserId);
    }

    _setupCallListener();
  }

  void _setupCallListener() {
    FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;

      if (widget.isIncoming && data['offer'] != null && !_isCallConnected) {
        await _callService.handleOffer(
          RTCSessionDescription(
            data['offer']['sdp'],
            data['offer']['type'],
          ),
        );
      }

      if (!widget.isIncoming && data['answer'] != null && !_isCallConnected) {
        await _callService.handleAnswer(
          RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          ),
        );
        setState(() => _isCallConnected = true);
      }

      if (data['status'] == 'ended') {
        Navigator.pop(context);
      }
    });

    // Listen for ICE candidates
    FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .collection('candidates')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _callService.handleRemoteCandidate(change.doc.data()!);
        }
      }
    });

    // Listen for remote stream
    if (_callService.peerConnection != null) {
      _callService.peerConnection!.onAddStream = (stream) {
        _remoteRenderer.srcObject = stream;
        setState(() => _isCallConnected = true);
      };
    }
  }

  void _toggleMicrophone() {
    if (_callService.localStream != null) {
      final audioTrack = _callService.localStream!
          .getAudioTracks()
          .firstWhere((track) => track.kind == 'audio');
      setState(() {
        _isMicMuted = !_isMicMuted;
        audioTrack.enabled = !_isMicMuted;
      });
    }
  }

  void _toggleCamera() {
    if (_callService.localStream != null) {
      final videoTrack = _callService.localStream!
          .getVideoTracks()
          .firstWhere((track) => track.kind == 'video');
      setState(() {
        _isCameraOff = !_isCameraOff;
        videoTrack.enabled = !_isCameraOff;
      });
    }
  }

  void _endCall() async {
    await _callService.endCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video
            _isCallConnected
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),

            // Local Video (Picture-in-Picture)
            Positioned(
              right: 20,
              top: 20,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

            // Call Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    backgroundColor: _isMicMuted ? Colors.red : Colors.white,
                    onPressed: _toggleMicrophone,
                    child: Icon(
                      _isMicMuted ? Icons.mic_off : Icons.mic,
                      color: _isMicMuted ? Colors.white : Colors.black,
                    ),
                  ),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _endCall,
                    child: const Icon(Icons.call_end),
                  ),
                  FloatingActionButton(
                    backgroundColor: _isCameraOff ? Colors.red : Colors.white,
                    onPressed: _toggleCamera,
                    child: Icon(
                      _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      color: _isCameraOff ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
