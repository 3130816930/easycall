import "dart:async";
import "package:socket_io_client/socket_io_client.dart" as IO;
import "package:shared_preferences/shared_preferences.dart";
import "../models/user_model.dart";
import "api_service.dart";

typedef CallOfferCallback = void Function(int fromUserId, String fromName, Map<String, dynamic> sdp);
typedef CallAnswerCallback = void Function(int fromUserId, Map<String, dynamic> sdp);
typedef IceCandidateCallback = void Function(int fromUserId, Map<String, dynamic> candidate);
typedef RemoteCommandCallback = void Function(String type, Map<String, dynamic> data, int fromUserId);
typedef RemoteScreenOfferCallback = void Function(int fromUserId, String fromName, Map<String, dynamic> sdp);
typedef RemoteScreenAnswerCallback = void Function(Map<String, dynamic> sdp);
typedef RemoteScreenIceCallback = void Function(Map<String, dynamic> candidate);

class WebSocketService {
  IO.Socket? _socket;
  bool _connected = false;
  Timer? _heartbeatTimer;

  CallOfferCallback? onCallOffer;
  CallAnswerCallback? onCallAnswer;
  IceCandidateCallback? onIceCandidate;
  VoidCallback? onCallEnded;
  VoidCallback? onPeerDisconnected;
  Function(int userId)? onCallError;
  RemoteCommandCallback? onRemoteCommand;
  RemoteScreenOfferCallback? onRemoteScreenOffer;
  RemoteScreenAnswerCallback? onRemoteScreenAnswer;
  RemoteScreenIceCallback? onRemoteScreenIce;

  bool get connected => _connected;
  void onCallErrorCallback(int userId) => onCallError?.call(userId);

  Future<bool> connect(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");
    if (token == null) return false;

    try {
      _socket = IO.io(serverUrl, {
        "transports": ["websocket"],
        "autoConnect": true,
        "auth": {"token": token},
      });

      _socket!.onConnect((_) {
        _connected = true;
        _startHeartbeat();
      });

      _socket!.onDisconnect((_) {
        _connected = false;
        _heartbeatTimer?.cancel();
      });

      _socket!.onConnectError((data) {});

      _socket!.on("presence", (data) {
        ApiService.updateFriendPresence(data["userId"], data["online"], data["inCall"]);
      });

      _socket!.on("friend_request", (data) {
        ApiService.addRequest(FriendRequestModel.fromJson(Map<String, dynamic>.from(data)));
      });

      _socket!.on("friend_added", (data) {
        if (data["user"] != null) {
          ApiService.addFriend(UserModel.fromJson(Map<String, dynamic>.from(data["user"])));
        }
      });

      _socket!.on("call:incoming", (data) {
        if (onCallOffer != null) {
          onCallOffer!(data["fromUserId"], data["fromName"], Map<String, dynamic>.from(data["sdp"]));
        }
      });

      _socket!.on("call:answered", (data) {
        if (onCallAnswer != null) {
          onCallAnswer!(data["fromUserId"], Map<String, dynamic>.from(data["sdp"]));
        }
      });

      _socket!.on("call:ice", (data) {
        if (onIceCandidate != null) {
          onIceCandidate!(data["fromUserId"], Map<String, dynamic>.from(data["candidate"]));
        }
      });

      _socket!.on("call:ended", (data) {
        onCallEnded?.call();
      });

      _socket!.on("call:peer_disconnected", (data) {
        onPeerDisconnected?.call();
      });

      _socket!.on("call:error", (data) {
        if (data["toUserId"] != null) onCallError?.call(data["toUserId"]);
      });

      _socket!.on("remote:screen_offer", (data) {
        if (onRemoteScreenOffer != null) {
          onRemoteScreenOffer!(data["fromUserId"], data["fromName"], Map<String, dynamic>.from(data["sdp"]));
        }
      });

      _socket!.on("remote:screen_answered", (data) {
        onRemoteScreenAnswer?.call(Map<String, dynamic>.from(data["sdp"]));
      });

      _socket!.on("remote:screen_ice", (data) {
        onRemoteScreenIce?.call(Map<String, dynamic>.from(data["candidate"]));
      });

      _socket!.on("remote:execute", (data) {
        if (onRemoteCommand != null) {
          onRemoteCommand!(data["type"], Map<String, dynamic>.from(data["data"]), data["fromUserId"]);
        }
      });

      _socket!.on("remote:error", (data) {});

      _socket!.connect();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _socket?.emit("heartbeat");
    });
  }

  void sendOffer(int toUserId, Map<String, dynamic> sdp) {
    _socket?.emit("call:offer", {"toUserId": toUserId, "sdp": sdp});
  }

  void sendAnswer(int toUserId, Map<String, dynamic> sdp) {
    _socket?.emit("call:answer", {"toUserId": toUserId, "sdp": sdp});
  }

  void sendIceCandidate(int toUserId, Map<String, dynamic> candidate) {
    _socket?.emit("call:ice", {"toUserId": toUserId, "candidate": candidate});
  }

  void endCall(int toUserId) {
    _socket?.emit("call:end", {"toUserId": toUserId});
  }

  void sendRemoteCommand(int toUserId, String type, Map<String, dynamic> data) {
    _socket?.emit("remote:command", {"toUserId": toUserId, "type": type, "data": data});
  }

  void sendScreenShareOffer(int viewerUserId, Map<String, dynamic> sdp) {
    _socket?.emit("remote:sharing", {"viewerUserId": viewerUserId, "sdp": sdp});
  }

  void sendScreenAnswer(int fromUserId, Map<String, dynamic> sdp) {
    _socket?.emit("remote:screen_answer", {"fromUserId": fromUserId, "sdp": sdp});
  }

  void sendScreenIce(int toUserId, Map<String, dynamic> candidate) {
    _socket?.emit("remote:screen_ice", {"toUserId": toUserId, "candidate": candidate});
  }

  void sendHeartbeat() {
    _socket?.emit("heartbeat");
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _socket?.disconnect();
    _socket = null;
    _connected = false;
  }
}
