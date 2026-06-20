import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// REST API 服务 — 负责登录、注册、好友管理等
class ApiService {
  // 将此地址改为你的服务器 IP
  static String baseUrl = 'http://192.168.1.100:3000';
  static String? _token;
  static UserModel? _currentUser;
  static List<UserModel> _friends = [];
  static List<FriendRequestModel> _requests = [];

  static UserModel? get currentUser => _currentUser;
  static List<UserModel> get friends => _friends;
  static List<FriendRequestModel> get requests => _requests;

  // ── 初始化：恢复登录状态 ──
  static Future<bool> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('current_user');
    if (_token != null && userJson != null) {
      _currentUser = UserModel.fromJson(jsonDecode(userJson));
      return true;
    }
    return false;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── 注册 ──
  static Future<Map<String, dynamic>> register(String phone, String name, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'name': name, 'password': password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _currentUser = UserModel.fromJson(data['user']);
        await _saveSession();
      }
      return data;
    } catch (e) {
      return {'error': '网络连接失败: $e'};
    }
  }

  // ── 登录 ──
  static Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _currentUser = UserModel.fromJson(data['user']);
        await _saveSession();
      }
      return data;
    } catch (e) {
      return {'error': '网络连接失败: $e'};
    }
  }

  // ── 设置长辈/普通模式 ──
  static Future<bool> setMode(String mode) async {
    if (_currentUser == null || _token == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/user/mode'),
        headers: _headers,
        body: jsonEncode({'mode': mode}),
      );
      if (res.statusCode == 200) {
        _currentUser = _currentUser!.copyWith(mode: mode);
        await _saveSession();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── 搜索用户 ──
  static Future<List<UserModel>> searchUsers(String query) async {
    if (_token == null) return [];
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/users/search?q=$query'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => UserModel.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── 发送好友请求 ──
  static Future<bool> sendFriendRequest(int toUserId) async {
    if (_token == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/friends/request'),
        headers: _headers,
        body: jsonEncode({'toUserId': toUserId}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── 获取好友请求列表 ──
  static Future<void> loadRequests() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/friends/requests'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _requests = data.map((e) => FriendRequestModel.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  // ── 接受/拒绝好友请求 ──
  static Future<bool> respondToRequest(int requestId, bool accept) async {
    if (_token == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/friends/respond'),
        headers: _headers,
        body: jsonEncode({'requestId': requestId, 'accept': accept}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── 获取好友列表 ──
  static Future<void> loadFriends() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/friends'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _friends = data.map((e) => UserModel.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  // ── 更新好友状态（来自 WebSocket 推送） ──
  static void updateFriendPresence(int userId, bool online, bool inCall) {
    final idx = _friends.indexWhere((f) => f.id == userId);
    if (idx >= 0) {
      _friends[idx] = _friends[idx].copyWith(online: online, inCall: inCall);
    }
  }

  // ── 添加好友（收到请求被接受后） ──
  static void addFriend(UserModel user) {
    if (_friends.any((f) => f.id == user.id)) return;
    _friends.add(user);
  }

  // ── 添加传入的好友请求 ──
  static void addRequest(FriendRequestModel req) {
    _requests.add(req);
  }

  static void removeRequest(int requestId) {
    _requests.removeWhere((r) => r.id == requestId);
  }

  // ── 会话持久化 ──
  static Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString('auth_token', _token!);
    if (_currentUser != null) {
      await prefs.setString('current_user', jsonEncode({
        'id': _currentUser!.id,
        'phone': _currentUser!.phone,
        'name': _currentUser!.name,
        'avatar': _currentUser!.avatar,
        'mode': _currentUser!.mode,
      }));
    }
  }

  // ── 登出 ──
  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _friends.clear();
    _requests.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');
  }
}
