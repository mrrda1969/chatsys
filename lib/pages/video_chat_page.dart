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
      // Initialize renderers
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      // Set up stream listeners
      _webRTCService.onLocalStreamAvailable = (MediaStream stream) {
        setState(() {
          _localStream = stream;
          _localRenderer.srcObject = stream;
        });
      };

      _webRTCService.onRemoteStreamAvailable = (MediaStream stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      };

      // Start or answer call based on call type
      if (widget.isIncomingCall && widget.callId != null) {
        // Listen for call status
        final callDoc = FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.callId);

        // Show incoming call dialog
        await _showIncomingCallDialog(callDoc);
      } else {
        await _webRTCService.startCall(widget.peerId);
      }

      setState(() {
        _isCallConnected = true;
      });
    } catch (e) {
      // Log the error and show a user-friendly error message
      print('Error initializing call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize call: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      // Automatically pop the page if call initialization fails
      Navigator.of(context).pop();
    }
  }

  // Show incoming call dialog with accept/reject options
  Future<void> _showIncomingCallDialog(DocumentReference callDoc) async {
    final completer = Completer<void>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Incoming Call'),
          content: const Text('You have an incoming video call'),
          actions: [
            TextButton(
              child: const Text('Reject'),
              onPressed: () async {
                // Reject the call
                await _webRTCService.rejectCall(
                  widget.callId!,
                  FirebaseAuth.instance.currentUser!.uid,
                );
                Navigator.of(context).pop();
                completer.complete();
                Navigator.of(context).pop(); // Close video chat page
              },
            ),
            ElevatedButton(
              child: const Text('Accept'),
              onPressed: () async {
                // Answer the call
                await _webRTCService.answerCall(widget.callId!);
                Navigator.of(context).pop();
                completer.complete();
              },
            ),
          ],
        );
      },
    );

    return completer.future;
  }

  void _toggleMute() {
    try {
      if (_localStream != null) {
        final audioTrack = _localStream!.getAudioTracks().first;
        setState(() {
          _isMuted = !_isMuted;
          audioTrack.enabled = !_isMuted;
        });
      } else {
        throw StateError('No local stream available');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to toggle mute: ${e.toString()}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _toggleVideo() {
    try {
      if (_localStream != null) {
        final videoTrack = _localStream!.getVideoTracks().first;
        setState(() {
          _isVideoEnabled = !_isVideoEnabled;
          videoTrack.enabled = _isVideoEnabled;
          _localRenderer.srcObject = _localStream;
        });
      } else {
        throw StateError('No local stream available');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to toggle video: ${e.toString()}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _endCall() {
    try {
      if (widget.callId != null) {
        _webRTCService.endCall(widget.callId!);
      }
      _webRTCService.cleanup();

      // Safe navigation check
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error ending call: $e');

      // Safe navigation and error display
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending call: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
      _webRTCService.cleanup();
    } catch (e) {
      print('Error during video chat page disposal: $e');
    } finally {
      super.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video (Full Screen)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

            // Local Video (Picture in Picture)
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    FloatingActionButton(
                      heroTag: 'mute',
                      backgroundColor: _isMuted ? Colors.red : Colors.white,
                      onPressed: _toggleMute,
                      child: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? Colors.white : Colors.black,
                      ),
                    ),

                    // End Call Button
                    FloatingActionButton(
                      heroTag: 'endCall',
                      backgroundColor: Colors.red,
                      onPressed: _endCall,
                      child: const Icon(Icons.call_end),
                    ),

                    // Video Toggle Button
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
            ),

            // Connection Status
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
          ],
        ),
      ),
    );
  }
}

// Helper function to navigate to video chat with enhanced error handling
void navigateToVideoChat(
  BuildContext context,
  String peerId, {
  String? callId,
}) {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start a video call')),
      );
      return;
    }

    // Use a try-catch block for navigation
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => VideoChatPage(
              peerId: peerId,
              isIncomingCall: callId != null,
              callId: callId,
            ),
      ),
    );
  } catch (e) {
    print('Navigation error in video chat: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to start video call: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
