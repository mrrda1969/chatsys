import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatsys/services/webrtc_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class VideoChatPage extends StatefulWidget {
  final String peerId;
  final bool isIncomingCall;
  final String? callId;
  final bool shouldReject;

  const VideoChatPage({
    super.key,
    required this.peerId,
    this.isIncomingCall = false,
    this.callId,
    this.shouldReject = false,
  });

  @override
  _VideoChatPageState createState() => _VideoChatPageState();
}

class _VideoChatPageState extends State<VideoChatPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final WebRTCService _webRTCService = WebRTCService();

  bool _isCallConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      _webRTCService.onLocalStreamAvailable = (MediaStream stream) {
        setState(() {
          _localStream = stream;
          _localRenderer.srcObject = stream;
        });
      };

      _webRTCService.onRemoteStreamAvailable = (MediaStream stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isCallConnected = true;
        });
      };

      if (widget.isIncomingCall && widget.callId != null) {
        if (widget.shouldReject) {
          await _webRTCService.rejectCall(
            widget.callId!,
            FirebaseAuth.instance.currentUser!.uid,
          );
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
        await _webRTCService.answerCall(widget.callId!);
      } else {
        await _webRTCService.startCall(widget.peerId);
      }
    } catch (e) {
      print('Error initializing call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _toggleMute() {
    if (_localStream == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _localStream!.getAudioTracks()[0].enabled = !_isMuted;
    });
  }

  void _toggleVideo() {
    if (_localStream == null) return;
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
      _localStream!.getVideoTracks()[0].enabled = _isVideoEnabled;
    });
  }

  void _endCall() async {
    try {
      if (widget.callId != null) {
        await _webRTCService.endCall(widget.callId!);
      }
      _webRTCService.cleanup();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error ending call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webRTCService.cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endCall();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
              Positioned(
                right: 20,
                top: 20,
                width: 100,
                height: 150,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
              if (!_isCallConnected)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          'Connecting...',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: 'mute',
                      backgroundColor: _isMuted ? Colors.red : Colors.white,
                      onPressed: _toggleMute,
                      child: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? Colors.white : Colors.black,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'endCall',
                      backgroundColor: Colors.red,
                      onPressed: _endCall,
                      child: const Icon(Icons.call_end),
                    ),
                    FloatingActionButton(
                      heroTag: 'video',
                      backgroundColor:
                          _isVideoEnabled ? Colors.white : Colors.red,
                      onPressed: _toggleVideo,
                      child: Icon(
                        _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                        color: _isVideoEnabled ? Colors.black : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void navigateToVideoChat(
  BuildContext context,
  String peerId, {
  String? callId,
  bool isIncomingCall = false,
  bool shouldReject = false,
}) {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start a video call')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => VideoChatPage(
              peerId: peerId,
              isIncomingCall: isIncomingCall,
              callId: callId,
              shouldReject: shouldReject,
            ),
      ),
    );
  } catch (e) {
    print('Navigation error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to start video call: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
