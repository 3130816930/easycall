import "dart:async";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "websocket_service.dart";

class WebRTCService {
  final WebSocketService _ws;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isInCall = false;
  int? _peerId;
  bool _speakerOn = false;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  Function(MediaStream stream)? onRemoteStreamAdded;

  bool get isInCall => _isInCall;
  int? get peerId => _peerId;

  WebRTCService(this._ws) {
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  static const Map<String, dynamic> _iceServers = {
    "iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
      {"urls": "stun:stun1.l.google.com:19302"},
    ]
  };

  Future<bool> initLocalMedia({bool video = true, bool audio = true}) async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        "audio": audio,
        "video": video ? {"facingMode": "user", "width": {"ideal": 720}, "height": {"ideal": 1280}} : false,
      });
      localRenderer.srcObject = _localStream;
      return true;
    } catch (e) {
      return false;
    }
  }

  void toggleMic() {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
    }
  }

  Future<void> toggleSpeaker() async {
    await Helper.setSpeakerphoneOn(!_speakerOn);
    _speakerOn = !_speakerOn;
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final tracks = _localStream!.getVideoTracks();
      if (tracks.isNotEmpty) await tracks.first.switchCamera();
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(_iceServers, {
      "mandatory": {"OfferToReceiveAudio": true, "OfferToReceiveVideo": true},
    });

    pc.onIceCandidate = (candidate) {
      if (_peerId != null && candidate != null) {
        _ws.sendIceCandidate(_peerId!, candidate.toMap());
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _cleanup();
      }
    };

    pc.onTrack = (event) {
      if (event.track.kind == "video") {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        if (onRemoteStreamAdded != null) onRemoteStreamAdded!(_remoteStream!);
      }
    };

    if (_localStream != null) pc.addStream(_localStream!);
    return pc;
  }

  Future<bool> startCall(int peerUserId) async {
    if (_isInCall) return false;
    _peerId = peerUserId;
    try {
      _peerConnection = await _createPeerConnection();
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _ws.sendOffer(peerUserId, offer.toMap());
      _isInCall = true;
      return true;
    } catch (e) {
      _cleanup();
      return false;
    }
  }

  Future<bool> answerCall(int fromUserId, Map<String, dynamic> offerSdp) async {
    _peerId = fromUserId;
    try {
      _peerConnection = await _createPeerConnection();
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerSdp["sdp"], offerSdp["type"]),
      );
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _ws.sendAnswer(fromUserId, answer.toMap());
      _isInCall = true;
      return true;
    } catch (e) {
      _cleanup();
      return false;
    }
  }

  Future<void> handleAnswer(Map<String, dynamic> answerSdp) async {
    if (_peerConnection == null) return;
    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answerSdp["sdp"], answerSdp["type"]),
      );
      if (onConnected != null) onConnected!();
    } catch (_) {}
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidate) async {
    if (_peerConnection == null) return;
    try {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(candidate["candidate"], candidate["sdpMid"], candidate["sdpMLineIndex"]),
      );
    } catch (_) {}
  }

  // ── Screen Sharing ──
  RTCPeerConnection? _screenPC;
  MediaStream? _screenStream;

  Future<MediaStream?> getScreenShareStream() async {
    try {
      return await navigator.mediaDevices.getDisplayMedia({
        "audio": false,
        "video": {"width": {"ideal": 720}, "height": {"ideal": 1280}, "frameRate": {"ideal": 15}},
      });
    } catch (_) {
      return null;
    }
  }

  Future<bool> startScreenSharing(int viewerUserId) async {
    final stream = await getScreenShareStream();
    if (stream == null) return false;
    _screenStream = stream;
    try {
      _screenPC = await createPeerConnection(_iceServers);
      _screenPC!.addStream(stream);
      _screenPC!.onIceCandidate = (candidate) {
        if (candidate != null) _ws.sendScreenIce(viewerUserId, candidate.toMap());
      };
      final offer = await _screenPC!.createOffer();
      await _screenPC!.setLocalDescription(offer);
      _ws.sendScreenShareOffer(viewerUserId, offer.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> handleScreenAnswer(Map<String, dynamic> answerSdp) async {
    if (_screenPC == null) return;
    await _screenPC!.setRemoteDescription(
      RTCSessionDescription(answerSdp["sdp"], answerSdp["type"]),
    );
  }

  Future<void> handleScreenIce(Map<String, dynamic> candidate) async {
    if (_screenPC == null) return;
    await _screenPC!.addCandidate(
      RTCIceCandidate(candidate["candidate"], candidate["sdpMid"], candidate["sdpMLineIndex"]),
    );
  }

  Future<RTCPeerConnection> createScreenViewerPC(int fromUserId) async {
    final pc = await createPeerConnection(_iceServers, {
      "mandatory": {"OfferToReceiveVideo": true, "OfferToReceiveAudio": false},
    });
    pc.onIceCandidate = (candidate) {
      if (candidate != null) _ws.sendScreenIce(fromUserId, candidate.toMap());
    };
    pc.onTrack = (event) {
      if (event.track.kind == "video") remoteRenderer.srcObject = event.streams[0];
    };
    return pc;
  }

  void stopScreenSharing() {
    _screenStream?.getTracks().forEach((t) => t.stop());
    _screenPC?.close();
    _screenPC = null;
    _screenStream = null;
  }

  void hangup() {
    if (_peerId != null) _ws.endCall(_peerId!);
    _cleanup();
  }

  void _cleanup() {
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream = null;
    _remoteStream = null;
    _isInCall = false;
    _peerId = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    if (onDisconnected != null) onDisconnected!();
  }

  void dispose() {
    _cleanup();
    localRenderer.dispose();
    remoteRenderer.dispose();
  }
}
