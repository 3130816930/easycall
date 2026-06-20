import "package:flutter/material.dart";
import "../models/user_model.dart";
import "../services/websocket_service.dart";
import "../services/webrtc_service.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";

class CallScreen extends StatefulWidget {
  final UserModel peerUser;
  final WebSocketService ws;
  final WebRTCService webrtc;
  final bool isCaller;

  const CallScreen({
    super.key, required this.peerUser, required this.ws,
    required this.webrtc, required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _micOn = true;
  bool _speakerOn = false;
  bool _callConnected = false;
  Duration _callDuration = Duration.zero;
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _setupCall();

    widget.webrtc.onConnected = () {
      if (mounted) {
        setState(() => _callConnected = true);
        _stopwatch.start();
      }
    };
    widget.webrtc.onDisconnected = () {
      if (mounted) _endCall();
    };
  }

  Future<void> _setupCall() async {
    final ok = await widget.webrtc.initLocalMedia();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("无法访问摄像头/麦克风，请授予权限")),
      );
      return;
    }

    if (widget.isCaller) {
      await widget.webrtc.startCall(widget.peerUser.id);
    }

    widget.ws.onCallAnswer = (fromUserId, sdp) async {
      await widget.webrtc.handleAnswer(sdp);
    };

    widget.ws.onIceCandidate = (fromUserId, candidate) async {
      await widget.webrtc.handleIceCandidate(candidate);
    };

    widget.ws.onCallEnded = () {
      if (mounted) _endCall();
    };

    widget.ws.onPeerDisconnected = () {
      if (mounted) _endCall();
    };

    if (!widget.isCaller) {
      widget.ws.onCallOffer = (fromUserId, fromName, sdp) async {
        if (fromUserId == widget.peerUser.id) {
          await widget.webrtc.answerCall(fromUserId, sdp);
        }
      };
    }
  }

  void _toggleMic() {
    widget.webrtc.toggleMic();
    setState(() => _micOn = !_micOn);
  }

  void _toggleSpeaker() {
    widget.webrtc.toggleSpeaker();
    setState(() => _speakerOn = !_speakerOn);
  }

  void _endCall() {
    _stopwatch.stop();
    widget.webrtc.hangup();
    if (mounted) Navigator.of(context).pop();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final s = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    final h = d.inHours > 0 ? "${d.inHours}:" : "";
    return "${h}${m}:${s}";
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Remote video (full screen)
          Container(color: Colors.black),
          if (widget.webrtc.remoteRenderer.textureId != null)
            RTCVideoView(widget.webrtc.remoteRenderer,
                fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          if (widget.webrtc.remoteRenderer.textureId == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white24,
                    child: Text(widget.peerUser.displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 40, color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                  Text(widget.peerUser.displayName,
                      style: const TextStyle(fontSize: 24, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    _callConnected ? _formatDuration(_callDuration) : "正在呼叫...",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),

          // Local video (PiP)
          Positioned(
            top: 60, right: 16,
            child: Container(
              width: 120, height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white38, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.webrtc.localRenderer.textureId != null
                    ? RTCVideoView(widget.webrtc.localRenderer,
                        mirror: true, fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                    : const Center(child: Icon(Icons.person, size: 48, color: Colors.white38)),
              ),
            ),
          ),

          // Controls
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Column(
              children: [
                StreamBuilder<Duration>(
                  stream: _callConnected ? Stream.periodic(const Duration(seconds: 1), (_) => _stopwatch.elapsed) : null,
                  builder: (_, snap) {
                    if (!_callConnected) return const SizedBox();
                    _callDuration = snap.data ?? _callDuration;
                    return Text(_formatDuration(_callDuration),
                        style: const TextStyle(fontSize: 16, color: Colors.white70));
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ctrlBtn(Icons.mic, _micOn ? Colors.white : Colors.redAccent, _toggleMic),
                    _ctrlBtn(Icons.volume_up, _speakerOn ? Colors.blueAccent : Colors.white, _toggleSpeaker),
                    _ctrlBtn(Icons.call_end, Colors.redAccent, _endCall, size: 60),
                    _ctrlBtn(Icons.switch_camera, Colors.white, () => widget.webrtc.switchCamera()),
                    _ctrlBtn(Icons.info_outline, Colors.white38, () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, Color color, VoidCallback onTap, {double size = 48}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
