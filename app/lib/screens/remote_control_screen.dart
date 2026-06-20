import "package:flutter/material.dart";
import "../models/user_model.dart";
import "../services/websocket_service.dart";
import "../services/webrtc_service.dart";
import "../services/remote_control_service.dart";

class RemoteControlScreen extends StatefulWidget {
  final UserModel peerUser;
  final WebSocketService ws;
  final WebRTCService webrtc;

  const RemoteControlScreen({
    super.key, required this.peerUser,
    required this.ws, required this.webrtc,
  });

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  bool _sharingScreen = false;
  bool _viewingScreen = false;
  bool _isViewer = false;

  @override
  void initState() {
    super.initState();
    // The caller (guardian) is the viewer
    // The receiver (elder) is the sharer
    _isViewer = ApiService.currentUser?.mode != "elder";
    if (_isViewer) {
      // Guardian: wait for screen share offer
      widget.ws.onRemoteScreenOffer = (fromUserId, fromName, sdp) async {
        final pc = await widget.webrtc.createScreenViewerPC(fromUserId);
        await pc.setRemoteDescription(
          RTCSessionDescription(sdp["sdp"], sdp["type"]),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        widget.ws.sendScreenAnswer(fromUserId, answer.toMap());
        setState(() => _viewingScreen = true);
      };
      widget.ws.onRemoteScreenIce = (candidate) async {
        await widget.webrtc.handleScreenIce(candidate);
      };
      // Ask elder to start sharing
      widget.ws.sendRemoteCommand(widget.peerUser.id, "start_screen_share", {});
    } else {
      // Elder: listen for start sharing command
      widget.ws.onRemoteCommand = (type, data, fromUserId) async {
        if (type == "start_screen_share" && fromUserId == widget.peerUser.id) {
          final ok = await widget.webrtc.startScreenSharing(widget.peerUser.id);
          if (ok && mounted) setState(() => _sharingScreen = true);
        }
      };
      widget.ws.onRemoteScreenAnswer = (sdp) async {
        await widget.webrtc.handleScreenAnswer(sdp);
      };
    }
  }

  void _sendTap() {
    if (!_isViewer) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("点击远程屏幕以发送点击命令")),
    );
  }

  void _sendSwipe() {
    if (!_isViewer) return;
    widget.ws.sendRemoteCommand(widget.peerUser.id, "swipe", {"x1": 300, "y1": 400, "x2": 100, "y2": 400, "duration": 300});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已发送滑动命令"), duration: Duration(seconds: 1)));
  }

  void _sendSystemAction(String action) {
    widget.ws.sendRemoteCommand(widget.peerUser.id, action, {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("已发送: ${_actionName(action)}"), duration: const Duration(seconds: 1)),
    );
  }

  void _openVideoPlayer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("播放视频"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            decoration: InputDecoration(
              hintText: "输入视频URL",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            controller: TextEditingController(text: "https://www.example.com/video.mp4"),
          ),
          const SizedBox(height: 16),
          ...VideoPlaybackHelper.sampleVideos.entries.map((e) => ListTile(
            title: Text(e.key),
            subtitle: Text(e.value, style: const TextStyle(fontSize: 11)),
            leading: const Icon(Icons.play_circle),
            onTap: () {
              widget.ws.sendRemoteCommand(
                widget.peerUser.id, "play_video", {"url": e.value, "title": e.key},
              );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("正在播放: ${e.key}")),
              );
            },
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("取消")),
          ElevatedButton(onPressed: () {
            // Use custom URL
            Navigator.of(ctx).pop();
          }, child: const Text("播放自定义视频")),
        ],
      ),
    );
  }

  String _actionName(String action) {
    switch (action) {
      case "back": return "返回键";
      case "home": return "Home键";
      case "recent": return "最近任务";
      default: return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("远程协助 - ${widget.peerUser.displayName}"),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Screen view area
          Expanded(
            child: Container(
              color: Colors.black87,
              child: _viewingScreen
                  ? (widget.webrtc.remoteRenderer.textureId != null
                      ? RTCVideoView(widget.webrtc.remoteRenderer,
                          fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
                      : const Center(child: CircularProgressIndicator(color: Colors.white)))
                  : (_sharingScreen
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.screen_share, size: 64, color: Colors.white54),
                              const SizedBox(height: 16),
                              const Text("正在共享屏幕...", style: TextStyle(color: Colors.white, fontSize: 18)),
                              const SizedBox(height: 8),
                              Text("${widget.peerUser.displayName} 可以查看你的屏幕",
                                  style: TextStyle(color: Colors.grey.shade400)),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_android, size: 64, color: Colors.grey.shade600),
                              const SizedBox(height: 16),
                              const Text("等待屏幕共享...", style: TextStyle(color: Colors.grey, fontSize: 18)),
                              const SizedBox(height: 8),
                              Text("正在建立连接", style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        )),
            ),
          ),

          // Control buttons (only for viewer - guardian)
          if (_isViewer)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // Navigation row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ctrlChip(Icons.arrow_back, "返回", () => _sendSystemAction("back")),
                      _ctrlChip(Icons.home, "主页", () => _sendSystemAction("home")),
                      _ctrlChip(Icons.swap_horiz, "最近", () => _sendSystemAction("recent")),
                      _ctrlChip(Icons.volume_up, "音量", () => {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ctrlChip(Icons.play_circle, "播放视频", _openVideoPlayer),
                      _ctrlChip(Icons.swipe, "左滑", _sendSwipe),
                      _ctrlChip(Icons.touch_app, "点击", _sendTap),
                      _ctrlChip(Icons.add_photo_alternate, "打开相册", () {
                        widget.ws.sendRemoteCommand(widget.peerUser.id, "open_app", {"package": "com.google.android.apps.photos"});
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("提示: 点击操作需配合屏幕坐标，建议使用预设按钮",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            // Elder: show simple message
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade900,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.screen_share, color: _sharingScreen ? Colors.greenAccent : Colors.white54),
                  const SizedBox(width: 8),
                  Text(
                    _sharingScreen ? "正在共享屏幕给 ${widget.peerUser.displayName}" : "等待对方控制...",
                    style: TextStyle(color: _sharingScreen ? Colors.greenAccent : Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _ctrlChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
