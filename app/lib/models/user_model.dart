/// 用户数据模型
class UserModel {
  final int id;
  final String phone;
  final String name;
  final String avatar;
  final String mode;   // 'normal' | 'elder'
  final String alias;
  final bool online;
  final bool inCall;

  UserModel({
    required this.id,
    required this.phone,
    required this.name,
    this.avatar = '',
    this.mode = 'normal',
    this.alias = '',
    this.online = false,
    this.inCall = false,
  });

  String get displayName => alias.isNotEmpty ? alias : name;

  bool get isElder => mode == 'elder';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      mode: json['mode'] ?? 'normal',
      alias: json['alias'] ?? '',
      online: json['online'] ?? false,
      inCall: json['inCall'] ?? false,
    );
  }

  UserModel copyWith({
    int? id,
    String? phone,
    String? name,
    String? avatar,
    String? mode,
    String? alias,
    bool? online,
    bool? inCall,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      mode: mode ?? this.mode,
      alias: alias ?? this.alias,
      online: online ?? this.online,
      inCall: inCall ?? this.inCall,
    );
  }
}

/// 好友请求模型
class FriendRequestModel {
  final int id;
  final int userId;
  final String phone;
  final String name;
  final String avatar;
  final String status;
  final String createdAt;

  FriendRequestModel({
    required this.id,
    required this.userId,
    required this.phone,
    required this.name,
    this.avatar = '',
    this.status = 'pending',
    this.createdAt = '',
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// 通话记录模型（未来扩展）
class CallLogModel {
  final int id;
  final int peerId;
  final String peerName;
  final String type;    // 'outgoing' | 'incoming'
  final String status;  // 'missed' | 'answered'
  final DateTime time;

  CallLogModel({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.type,
    required this.status,
    required this.time,
  });
}
