import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/contacts_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String contactId;
  final bool isIncoming;
  final String? callId;

  const VideoCallScreen({
    super.key,
    required this.contactId,
    this.isIncoming = false,
    this.callId,
  });

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final ContactsService _contactsService = ContactsService();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  String? _currentCallId;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupCallService();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupCallService() {
    // Set up stream availability callbacks with error handling
    _webRTCService.onLocalStreamAvailable = (stream) {
      try {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      } catch (e) {
        print('Error setting local stream: $e');
      }
    };

    _webRTCService.onRemoteStreamAvailable = (stream) {
      try {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      } catch (e) {
        print('Error setting remote stream: $e');
        // Optionally show a snackbar or dialog about stream issues
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Problem with remote video stream: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    // Initiate or answer call based on type
    _initiateOrAnswerCall();
  }

  Future<void> _initiateOrAnswerCall() async {
    try {
      if (widget.isIncoming && widget.callId != null) {
        // Answering an incoming call
        await _webRTCService.answerCall(widget.callId!);
        setState(() {
          _currentCallId = widget.callId;
        });
      } else {
        // Initiating a new call
        final callId = await _webRTCService.startCall(widget.contactId);
        if (callId == null) {
          throw Exception('Failed to initiate call');
        }
        setState(() {
          _currentCallId = callId;
        });
      }
    } catch (e) {
      print('Error initiating/answering call: $e');

      // Show detailed error dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Call Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Failed to start/answer call:'),
              const SizedBox(height: 10),
              Text(
                e.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Navigate back
      Navigator.of(context).pop();
    }
  }

  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
      final videoTracks = _webRTCService.getLocalVideoTracks();
      if (videoTracks != null && videoTracks.isNotEmpty) {
        videoTracks.first.enabled = _isVideoEnabled;
      }
    });
  }

  void _toggleAudio() {
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
      final audioTracks = _webRTCService.getLocalAudioTracks();
      if (audioTracks != null && audioTracks.isNotEmpty) {
        audioTracks.first.enabled = _isAudioEnabled;
      }
    });
  }

  void _endCall() async {
    // End the call if we have a call ID
    if (_currentCallId != null) {
      await _webRTCService.endCall(_currentCallId!);
    }

    // Cleanup resources
    _webRTCService.cleanup();

    // Navigate back
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video view (Large frame)
            Positioned.fill(
              child: RTCVideoView(_remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),

            // Local video view (Small overlay)
            Positioned(
              top: 40,
              right: 20,
              width: 120,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RTCVideoView(_localRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            ),

            // Call controls
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute/Unmute Audio
                  IconButton(
                    icon: Icon(
                      _isAudioEnabled ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: _toggleAudio,
                  ),

                  // Video On/Off
                  IconButton(
                    icon: Icon(
                      _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: _toggleVideo,
                  ),

                  // End Call
                  IconButton(
                    icon: const Icon(
                      Icons.call_end,
                      color: Colors.red,
                      size: 36,
                    ),
                    onPressed: _endCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webRTCService.cleanup();
    super.dispose();
  }
}
