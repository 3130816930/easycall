# EasyCall — 让长辈也能轻松视频通话与远程协助

一个专为不擅长使用智能手机的长辈设计的 Android 应用，实现一键视频通话（无需对方接听）和远程协助功能。

---

## 核心功能

| 功能 | 说明 |
|------|------|
| **视频通话** | 基于 WebRTC 的点对点高清视频通话 |
| **自动接听** | 长辈端无需任何操作，视频自动接通 |
| **好友在线** | 手机开机即显示在线状态，随时可拨打 |
| **忙线检测** | 通话中自动显示"忙碌"，避免打扰 |
| **远程协助** | 查看长辈屏幕 + 远程点击/滑动/打开应用/播放视频 |
| **长辈模式** | 超大按钮极简界面，仅有"点击好友→通话"一步操作 |
| **普通模式** | 完整的好友管理、通话控制、远程协助界面 |

## 系统架构

```
┌─────────────────────┐         ┌──────────────────────┐
│  长辈手机 (Elder)   │         │  家人手机 (Guardian)  │
│                     │         │                      │
│  EasyCall App       │◄──────►│  EasyCall App        │
│  · 长辈模式(超大UI)  │  WebRTC │  · 普通模式(完整功能) │
│  · 自动接听         │  P2P    │  · 好友管理与在线状态 │
│  · 屏幕共享(被控端)  │         │  · 发起通话           │
│  · 接收远程命令      │         │  · 远程协助(控制端)   │
│                     │         │                      │
└─────────┬───────────┘         └───────────┬───────────┘
          │                                 │
          │      ┌──────────────────┐       │
          └─────►│   Node.js 后端   │◄──────┘
                 │                  │
                 │  · 信令服务      │
                 │  · 在线状态      │
                 │  · 好友关系管理  │
                 │  · 命令中继      │
                 │  · SQLite 数据库 │
                 └──────────────────┘
```

## 技术栈

### 后端 (Node.js)
- **运行环境**: Node.js ≥ 16
- **核心**: Express + Socket.IO
- **数据库**: SQLite (无需额外安装)
- **认证**: JWT + bcrypt

### 移动端 (Flutter)
- **框架**: Flutter 3.x
- **视频通话**: `flutter_webrtc` (WebRTC)
- **实时通信**: `socket_io_client`
- **屏幕共享**: WebRTC getDisplayMedia
- **远程触摸**: Android AccessibilityService (GestureDescription)
- **前台保活**: Android ForegroundService

---

## 快速开始

### 1. 部署后端服务器

需要在有公网 IP 或家庭局域网内的一台电脑/云服务器上运行。

```bash
# 进入后端目录
cd backend

# 安装依赖
npm install

# 启动服务器
npm start

# 服务器运行在 http://0.0.0.0:3000
```

> 注: 如果使用家庭局域网，需要保证手机和服务器在同一 Wi-Fi 下。
> 如需外网访问，请将服务器部署到云服务器（如阿里云、腾讯云等）。

### 2. 构建 Android App

#### 方式一：使用 Flutter CLI 构建（推荐）

```bash
# 安装 Flutter SDK
# 参见 https://flutter.dev/docs/get-started/install

# 进入 app 目录
cd app

# 安装 Flutter 依赖
flutter pub get

# 连接 Android 手机，构建并安装
flutter run --release

# 或生成 APK 安装包
flutter build apk --release
```

#### 方式二：使用 Android Studio

1. 打开 `app/android` 目录
2. 等待 Gradle 同步完成
3. 连接手机 → Run

### 3. 配置服务器地址

安装后第一次使用，需要设置服务器地址：

1. 打开 EasyCall
2. 右上角菜单 → **服务器设置**
3. 输入服务器地址：`http://<你的服务器IP>:3000`
4. 保存

> 家庭局域网示例：`http://192.168.1.100:3000`

### 4. 注册和添加好友

1. 注册两个账号：一个作为"家人"（监护人），一个作为"长辈"
2. 在家人手机上搜索长辈的手机号/昵称，发送好友请求
3. 在长辈手机上同意请求
4. 将长辈手机切换为**长辈模式**（右上角菜单 → 切换为长辈模式）

### 5. 启用远程控制辅助功能

> 远程控制需要 Android 辅助功能权限

1. 打开手机 **设置 → 辅助功能 → 已安装的服务**
2. 找到 **EasyCall** 并开启
3. 确认授权

### 6. 开始使用

#### 长辈手机（长辈模式）
- 开机即显示在线的家人列表
- 点击家人的**大按钮**→**自动拨通视频通话**
- 对方挂断后自动回到主页

#### 家人手机（普通模式）
- 查看好友在线/忙碌状态
- 点击好友 → 视频通话
- 点击远程协助按钮 → 查看长辈屏幕 + 执行操作

---

## 远程控制操作说明

| 操作 | 说明 | 需要权限 |
|------|------|----------|
| 查看屏幕 | WebRTC 屏幕共享 | 屏幕录制授权 |
| 模拟点击 | 在指定坐标点击 | 辅助功能 |
| 模拟滑动 | 从 A 滑到 B | 辅助功能 |
| 返回键 | 模拟系统返回 | 辅助功能 |
| Home键 | 回到桌面 | 辅助功能 |
| 播放视频 | 在长辈手机打开视频 | 无 |
| 打开应用 | 启动指定 App | 无 |
| 调整音量 | 调大/调小音量 | 无 |

---

## 项目结构

```
easycall/
├── backend/                    # Node.js 后端服务器
│   ├── package.json
│   ├── config.js               # 配置文件（STUN/TURN 等）
│   └── server.js               # 服务器主程序
│
├── app/                        # Flutter 移动端
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart           # 应用入口
│   │   ├── models/
│   │   │   └── user_model.dart # 用户/好友/请求模型
│   │   ├── services/
│   │   │   ├── api_service.dart         # REST API 服务
│   │   │   ├── websocket_service.dart    # WebSocket 实时通信
│   │   │   ├── webrtc_service.dart       # WebRTC 视频通话
│   │   │   └── remote_control_service.dart # 远程控制服务
│   │   ├── screens/
│   │   │   ├── login_screen.dart         # 登录/注册
│   │   │   ├── home_screen.dart          # 主页（好友列表/长辈模式）
│   │   │   ├── call_screen.dart          # 视频通话界面
│   │   │   └── remote_control_screen.dart # 远程控制界面
│   │   └── widgets/
│   └── android/                # Android 平台配置
│       ├── build.gradle
│       ├── settings.gradle
│       ├── app/
│       │   ├── build.gradle
│       │   └── src/main/
│       │       ├── AndroidManifest.xml
│       │       ├── java/com/easycall/app/
│       │       │   ├── MainActivity.java
│       │       │   ├── EasyCallAccessibilityService.java  # 辅助功能(远程触摸)
│       │       │   ├── EasyCallForegroundService.java     # 前台保活服务
│       │       │   └── AudioUtils.java
│       │       └── res/
│       │           ├── values/
│       │           ├── xml/
│       │           └── ...
│       └── gradle/wrapper/
│
└── README.md
```

---

## 环境要求

### 后端服务器
- **Node.js** ≥ 16.x
- **npm** ≥ 8.x
- 操作系统: Windows / Linux / macOS 均可

### 开发环境（构建 App）
- **Flutter SDK** ≥ 3.0
- **Android Studio** (推荐)
- **Java JDK** 11+ (Android Gradle 需要)

### 运行环境（手机）
- **Android** 7.0 (API 24) 或更高
- 建议: Android 10+ 以获得最佳 WebRTC 体验
- 如需远程控制（触摸模拟）: Android 7.0+ (API 24+)

---

## 常见问题

### Q: 为什么视频打不通？
A: 检查以下几点：
- 服务器是否正常运行
- 手机和服务器网络是否连通
- 好友是否在线（显示绿色圆点）
- 是否授予了摄像头/麦克风权限

### Q: 远程控制点了没反应？
A: 需要在长辈手机上开启辅助功能：
设置 → 辅助功能 → EasyCall → 开启

### Q: 能通过外网使用吗？
A: 可以。将后端部署到云服务器（需要公网 IP），然后在 App 中设置云服务器地址即可。

### Q: 视频质量如何？
A: 取决于网络。家庭局域网内为高清（720p），外网受限于上行带宽。可以在 `webrtc_service.dart` 中调整视频参数。

### Q: 支持 iOS 吗？
A: 当前为 Android 版。Flutter 代码可以编译到 iOS，但远程控制的辅助功能需要 iOS 版本的实现调整。

---

## 安全说明

- 当前使用 JWT 进行身份认证
- 所有通信默认使用 HTTP/WebSocket (ws://)
- 如需安全传输，建议:
  1. 后端配置 HTTPS/WSS
  2. 部署 TURN 服务器（用于 NAT 穿透）
  3. 修改 JWT_SECRET 为强密码

---

## 许可

本项目仅供个人和家庭使用。
