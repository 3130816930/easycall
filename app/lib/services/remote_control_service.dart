/// 远程控制服务
/// 在"长辈"手机上接收远程命令并执行
/// 在"监护人"手机上发送远程命令
///
/// 远程控制通过 Android Accessibility Service 实现触摸模拟，
/// 同时使用 WebRTC 屏幕共享让监护人看到长辈手机屏幕。

/// 可发送/接收的远程命令类型
class RemoteCommandType {
  static const String tap = 'tap';
  static const String swipe = 'swipe';
  static const String openApp = 'open_app';
  static const String back = 'back';
  static const String home = 'home';
  static const String recent = 'recent';
  static const String playVideo = 'play_video';
  static const String openPhoto = 'open_photo';
  static const String volume = 'volume';
  static const String longPress = 'long_press';
  static const String inputText = 'input_text';
}

class RemoteCommand {
  final String type;
  final Map<String, dynamic> data;
  final int fromUserId;

  RemoteCommand({required this.type, required this.data, required this.fromUserId});

  factory RemoteCommand.fromMap(Map<String, dynamic> map, int fromUserId) {
    return RemoteCommand(
      type: map['type'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      fromUserId: fromUserId,
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'data': data};
}

class RemoteControlService {
  static final RemoteControlService _instance = RemoteControlService._();
  factory RemoteControlService() => _instance;
  RemoteControlService._();

  bool _isControlling = false;
  int? _targetUserId;

  bool get isControlling => _isControlling;
  int? get targetUserId => _targetUserId;

  void startControlling(int targetUserId) {
    _isControlling = true;
    _targetUserId = targetUserId;
  }

  void stopControlling() {
    _isControlling = false;
    _targetUserId = null;
  }

  static Map<String, dynamic> tapCommand(double x, double y) {
    return {'type': RemoteCommandType.tap, 'data': {'x': x, 'y': y}};
  }

  static Map<String, dynamic> swipeCommand(double x1, double y1, double x2, double y2, {int duration = 300}) {
    return {'type': RemoteCommandType.swipe, 'data': {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'duration': duration}};
  }

  static Map<String, dynamic> openAppCommand(String packageName) {
    return {'type': RemoteCommandType.openApp, 'data': {'package': packageName}};
  }

  static Map<String, dynamic> playVideoCommand(String url, String title) {
    return {'type': RemoteCommandType.playVideo, 'data': {'url': url, 'title': title}};
  }

  static Map<String, dynamic> systemKeyCommand(String key) {
    return {'type': key, 'data': {}};
  }

  static Map<String, dynamic> volumeCommand(bool up) {
    return {'type': RemoteCommandType.volume, 'data': {'up': up}};
  }
}

class VideoPlaybackHelper {
  static Map<String, dynamic> playOnElderPhone(String videoUrl, String title) {
    return RemoteControlService.playVideoCommand(videoUrl, title);
  }

  static const Map<String, String> sampleVideos = {
    '风景视频': 'https://www.example.com/scenery.mp4',
    '戏曲': 'https://www.example.com/opera.mp4',
    '养生视频': 'https://www.example.com/health.mp4',
  };
}
