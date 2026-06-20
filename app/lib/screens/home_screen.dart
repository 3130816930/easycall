import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/webrtc_service.dart';
import 'login_screen.dart';
import 'call_screen.dart';
import 'remote_control_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final WebSocketService _ws = WebSocketService();
  final WebRTCService _webrtc = WebRTCService(WebSocketService());
  bool _loading = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ws.disconnect();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendHeartbeat();
    }
  }

  void _sendHeartbeat() {
    // WS handles heartbeat automatically
  }

  Future<void> _init() async {
    final user = ApiService.currentUser;
    if (user == null) return;
    await Future.wait([ApiService.loadFriends(), ApiService.loadRequests()]);
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url') ?? ApiService.baseUrl;
    if (serverUrl.isNotEmpty) {
      final ok = await _ws.connect(serverUrl);
      setState(() => _connected = ok);
    }
    setState(() => _loading = false);
  }

  void _startCall(UserModel friend) {
    if (friend.inCall) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("对方正在通话中")));
      return;
    }
    if (!friend.online) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("对方不在线")));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(peerUser: friend, ws: _ws, webrtc: _webrtc, isCaller: true),
    ));
  }

  void _startRemoteControl(UserModel friend) {
    if (!friend.online) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("对方不在线")));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteControlScreen(peerUser: friend, ws: _ws, webrtc: _webrtc),
    ));
  }

  Future<void> _refresh() async {
    await ApiService.loadFriends();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isElder = ApiService.currentUser?.mode == "elder";
    return Scaffold(
      appBar: AppBar(
        title: Text(isElder ? "EasyCall · 长辈模式" : "EasyCall"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(_connected ? Icons.wifi : Icons.wifi_off,
                color: _connected ? Colors.greenAccent : Colors.redAccent, size: 20),
          ),
          if (!isElder)
            PopupMenuButton<String>(onSelected: (v) async {
              if (v == "search") _showSearchDialog();
              else if (v == "mode") {
                final nm = ApiService.currentUser?.mode == "elder" ? "normal" : "elder";
                await ApiService.setMode(nm);
                setState(() {});
              } else if (v == "server") _showServerDialog();
              else if (v == "logout") {
                _ws.disconnect();
                await ApiService.logout();
                if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            }, itemBuilder: (_) => [
              const PopupMenuItem(value: "search", child: ListTile(leading: Icon(Icons.search), title: Text("添加好友"), dense: true)),
              PopupMenuItem(value: "mode", child: ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(ApiService.currentUser?.mode == "elder" ? "切换为普通模式" : "切换为长辈模式"),
                dense: true,
              )),
              const PopupMenuItem(value: "server", child: ListTile(leading: Icon(Icons.settings), title: Text("服务器设置"), dense: true)),
              const PopupMenuItem(value: "logout", child: ListTile(leading: Icon(Icons.exit_to_app), title: Text("退出登录"), dense: true)),
            ]),
        ],
      ),
      body: isElder ? _buildElderLayout() : _buildNormalLayout(),
    );
  }

  Widget _buildNormalLayout() {
    final friends = ApiService.friends;
    final requests = ApiService.requests;
    return Column(
      children: [
        if (requests.isNotEmpty)
          Container(
            width: double.infinity,
            color: Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.person_add, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text("${requests.length} 个好友请求", style: TextStyle(color: Colors.orange.shade900))),
              TextButton(onPressed: () => _showRequestsDialog(requests), child: const Text("查看")),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            const Icon(Icons.people, size: 20),
            const SizedBox(width: 8),
            Text("我的好友 (${friends.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text("在线: ${friends.where((f) => f.online).length}", style: TextStyle(color: Colors.grey.shade600)),
          ]),
        ),
        Expanded(
          child: friends.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text("还没有好友", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    TextButton.icon(onPressed: () => _showSearchDialog(), icon: const Icon(Icons.person_add), label: const Text("添加好友")),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: friends.length,
                    itemBuilder: (_, i) => _buildFriendCard(friends[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(UserModel friend) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _startCall(friend),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: friend.online ? Colors.green.shade100 : Colors.grey.shade200,
              child: Text(
                friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : "?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: friend.online ? Colors.green.shade700 : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: friend.inCall ? Colors.orange : friend.online ? Colors.green : Colors.grey,
                  )),
                  const SizedBox(width: 6),
                  Text(friend.inCall ? "通话中" : friend.online ? "在线" : "离线",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  if (friend.isElder) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text("长辈", style: TextStyle(fontSize: 10, color: Colors.orange.shade800)),
                    ),
                  ],
                ]),
              ],
            )),
            if (friend.online) Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(Icons.videocam, color: friend.inCall ? Colors.grey : Colors.blue.shade600),
                onPressed: friend.inCall ? null : () => _startCall(friend),
                tooltip: "视频通话",
              ),
              if (!friend.inCall)
                IconButton(
                  icon: Icon(Icons.phone_android, color: Colors.purple.shade500),
                  onPressed: () => _startRemoteControl(friend),
                  tooltip: "远程协助",
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildElderLayout() {
    final friends = ApiService.friends.where((f) => f.online).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),
        Text("点击下方好友\n即可视频通话", textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, color: Colors.grey.shade700, height: 1.4)),
        const SizedBox(height: 32),
        Expanded(
          child: friends.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.signal_wifi_off, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text("暂无好友在线", style: TextStyle(fontSize: 22, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Text("打开手机即可连接", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  ],
                ))
              : ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: double.infinity, height: 90,
                      child: ElevatedButton.icon(
                        onPressed: () => _startCall(friend),
                        icon: Icon(friend.inCall ? Icons.phone_in_talk : Icons.videocam,
                            size: 36, color: friend.inCall ? Colors.orange : Colors.white),
                        label: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(friend.displayName, style: const TextStyle(fontSize: 28)),
                          Text(friend.inCall ? "通话中..." : "在线",
                              style: TextStyle(fontSize: 14, color: friend.inCall ? Colors.orange.shade200 : Colors.white70)),
                        ]),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: friend.inCall ? Colors.orange.shade700 : Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  void _showSearchDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("添加好友"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, autofocus: true,
          decoration: InputDecoration(hintText: "输入手机号或昵称", prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<UserModel>>(
          future: ApiService.searchUsers(""),
          builder: (_, snap) {
            if (!snap.hasData || snap.data!.isEmpty) {
              return Padding(padding: const EdgeInsets.all(16),
                  child: Text("输入手机号搜索用户", style: TextStyle(color: Colors.grey.shade600)));
            }
            return SizedBox(height: 200, child: ListView.builder(
              itemCount: snap.data!.length,
              itemBuilder: (_, i) {
                final u = snap.data![i];
                return ListTile(
                  leading: CircleAvatar(child: Text(u.name[0])),
                  title: Text(u.name), subtitle: Text(u.phone),
                  trailing: IconButton(icon: const Icon(Icons.person_add), onPressed: () async {
                    await ApiService.sendFriendRequest(u.id);
                    Navigator.of(ctx).pop();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已向 ${u.name} 发送好友请求")));
                  }),
                );
              },
            ));
          },
        ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("取消"))],
    ));
  }

  void _showRequestsDialog(List<FriendRequestModel> requests) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("好友请求"),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(
        shrinkWrap: true, itemCount: requests.length,
        itemBuilder: (_, i) {
          final r = requests[i];
          return ListTile(
            leading: CircleAvatar(child: Text(r.name[0])),
            title: Text(r.name), subtitle: Text(r.phone),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () async {
                await ApiService.respondToRequest(r.id, true);
                ApiService.removeRequest(r.id);
                await ApiService.loadFriends();
                if (mounted) setState(() {});
                Navigator.of(ctx).pop();
              }),
              IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () async {
                await ApiService.respondToRequest(r.id, false);
                ApiService.removeRequest(r.id);
                if (mounted) setState(() {});
                Navigator.of(ctx).pop();
              }),
            ]),
          );
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("关闭"))],
    ));
  }

  void _showServerDialog() {
    final ctrl = TextEditingController(text: ApiService.baseUrl);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("服务器设置"),
      content: TextField(controller: ctrl,
        decoration: InputDecoration(labelText: "服务器地址", hintText: "http://192.168.1.100:3000",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("取消")),
        ElevatedButton(onPressed: () async {
          ApiService.baseUrl = ctrl.text.trim();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("server_url", ApiService.baseUrl);
          Navigator.of(ctx).pop();
          _ws.disconnect();
          final ok = await _ws.connect(ApiService.baseUrl);
          setState(() => _connected = ok);
        }, child: const Text("保存")),
      ],
    ));
  }
}
