const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const path = require("path");
const fs = require("fs");
const initSqlJs = require("sql.js");

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "easycall_secret_key_change_in_production";
const DB_PATH = path.join(__dirname, "easycall.db");

let db;
const fileBuffer = fs.existsSync(DB_PATH) ? fs.readFileSync(DB_PATH) : null;

async function initDb() {
  const SQL = await initSqlJs();
  db = fileBuffer ? new SQL.Database(fileBuffer) : new SQL.Database();
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    password TEXT NOT NULL,
    avatar TEXT DEFAULT "",
    mode TEXT DEFAULT "normal",
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
  db.run(`CREATE TABLE IF NOT EXISTS friends (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    friend_id INTEGER NOT NULL,
    alias TEXT DEFAULT "",
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, friend_id)
  )`);
  db.run(`CREATE TABLE IF NOT EXISTS friend_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_user_id INTEGER NOT NULL,
    to_user_id INTEGER NOT NULL,
    status TEXT DEFAULT "pending",
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
  saveDb();
}

function saveDb() { fs.writeFileSync(DB_PATH, Buffer.from(db.export())); }
function dbGet(sql, p = []) { const s = db.prepare(sql); s.bind(p); let r = null; if (s.step()) r = s.getAsObject(); s.free(); return r; }
function dbAll(sql, p = []) { const s = db.prepare(sql); s.bind(p); const r = []; while (s.step()) r.push(s.getAsObject()); s.free(); return r; }
function dbRun(sql, p = []) { db.run(sql, p); saveDb(); const x = db.exec("SELECT last_insert_rowid() as id"); return x.length > 0 ? x[0].values[0][0] : null; }

const app = express();
app.use(cors());
app.use(express.json());
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*", methods: ["GET", "POST"] } });

const onlineUsers = new Map();
const userSockets = new Map();

function authM(req, res, next) {
  const t = req.headers.authorization?.split(" ")[1];
  if (!t) return res.status(401).json({ error: "未授权" });
  try { req.user = jwt.verify(t, JWT_SECRET); next(); } catch { res.status(401).json({ error: "Token 无效" }); }
}
function ioAuth(s, n) {
  const t = s.handshake.auth?.token;
  if (!t) return n(new Error("无Token"));
  try { s.user = jwt.verify(t, JWT_SECRET); n(); } catch { n(new Error("Token无效")); }
}

// ════════════════════════════════════════
//  🏠 根路径 — 交互版 App 界面
// ════════════════════════════════════════
app.get("/", (req, res) => {
  const htmlPath = path.join(__dirname, "..", "interactive.html");
  if (fs.existsSync(htmlPath)) {
    let html = fs.readFileSync(htmlPath, "utf8");
    // Fix API URL to same origin
    html = html.replace('const API = "http://localhost:3000"', 'const API = window.location.origin');
    res.set("Content-Type", "text/html; charset=utf-8").send(html);
  } else {
    res.send("Interactive app not found. Run: cd backend && node server.js");
  }
});

// ════════════════════════════════════════
//  REST API
// ════════════════════════════════════════
app.post("/api/register", async (req, res) => {
  try {
    const { phone, name, password } = req.body;
    if (!phone || !name || !password) return res.status(400).json({ error: "缺少必填字段" });
    if (dbGet("SELECT id FROM users WHERE phone = ?", [phone])) return res.status(409).json({ error: "该手机号已注册" });
    const hashed = await bcrypt.hash(password, 10);
    const id = dbRun("INSERT INTO users (phone, name, password) VALUES (?, ?, ?)", [phone, name, hashed]);
    const token = jwt.sign({ id, phone, name }, JWT_SECRET, { expiresIn: "365d" });
    res.json({ token, user: { id, phone, name, mode: "normal" } });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post("/api/login", async (req, res) => {
  try {
    const { phone, password } = req.body;
    const user = dbGet("SELECT * FROM users WHERE phone = ?", [phone]);
    if (!user) return res.status(404).json({ error: "用户不存在" });
    if (!(await bcrypt.compare(password, user.password))) return res.status(401).json({ error: "密码错误" });
    const token = jwt.sign({ id: user.id, phone: user.phone, name: user.name }, JWT_SECRET, { expiresIn: "365d" });
    res.json({ token, user: { id: user.id, phone: user.phone, name: user.name, avatar: user.avatar, mode: user.mode } });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get("/api/user", authM, (req, res) => {
  const u = dbGet("SELECT id, phone, name, avatar, mode, created_at FROM users WHERE id = ?", [req.user.id]);
  if (!u) return res.status(404).json({ error: "用户不存在" });
  res.json(u);
});

app.post("/api/user/mode", authM, (req, res) => {
  const { mode } = req.body;
  if (!["normal", "elder"].includes(mode)) return res.status(400).json({ error: "无效模式" });
  dbRun("UPDATE users SET mode = ? WHERE id = ?", [mode, req.user.id]);
  res.json({ success: true, mode });
});

app.get("/api/users/search", authM, (req, res) => {
  const q = req.query.q || "";
  res.json(dbAll("SELECT id, phone, name, avatar, mode FROM users WHERE (phone LIKE ? OR name LIKE ?) AND id != ? LIMIT 20", [`%${q}%`, `%${q}%`, req.user.id]));
});

app.post("/api/friends/request", authM, (req, res) => {
  const { toUserId } = req.body;
  if (toUserId === req.user.id) return res.status(400).json({ error: "不能添加自己" });
  if (dbGet("SELECT id FROM friends WHERE user_id = ? AND friend_id = ?", [req.user.id, toUserId])) return res.status(409).json({ error: "已是好友" });
  try {
    const id = dbRun("INSERT OR IGNORE INTO friend_requests (from_user_id, to_user_id) VALUES (?, ?)", [req.user.id, toUserId]);
    const from = dbGet("SELECT id, phone, name, avatar FROM users WHERE id = ?", [req.user.id]);
    const s = userSockets.get(toUserId);
    if (s && from) s.forEach(sid => io.to(sid).emit("friend_request", { id, fromUser: from, status: "pending" }));
    res.json({ success: true, requestId: id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get("/api/friends/requests", authM, (req, res) => {
  res.json(dbAll(`SELECT fr.id, fr.status, fr.created_at, u.id as user_id, u.phone, u.name, u.avatar FROM friend_requests fr JOIN users u ON fr.from_user_id = u.id WHERE fr.to_user_id = ? AND fr.status = "pending" ORDER BY fr.created_at DESC`, [req.user.id]));
});

app.post("/api/friends/respond", authM, (req, res) => {
  const { requestId, accept } = req.body;
  dbRun("UPDATE friend_requests SET status = ? WHERE id = ? AND to_user_id = ?", [accept ? "accepted" : "rejected", requestId, req.user.id]);
  if (accept) {
    const d = dbGet("SELECT from_user_id FROM friend_requests WHERE id = ?", [requestId]);
    if (d) dbRun("INSERT OR IGNORE INTO friends (user_id, friend_id) VALUES (?, ?), (?, ?)", [req.user.id, d.from_user_id, d.from_user_id, req.user.id]);
  }
  res.json({ success: true, status: accept ? "accepted" : "rejected" });
});

app.get("/api/friends", authM, (req, res) => {
  const rows = dbAll(`SELECT u.id, u.phone, u.name, u.avatar, u.mode, COALESCE(f.alias, "") as alias FROM friends f JOIN users u ON f.friend_id = u.id WHERE f.user_id = ? ORDER BY u.name`, [req.user.id]);
  res.json(rows.map(f => ({ ...f, online: onlineUsers.has(f.id), inCall: onlineUsers.get(f.id)?.inCall || false })));
});

// ════════════════════════════════════════
//  Socket.IO
// ════════════════════════════════════════
io.use(ioAuth);
io.on("connection", (socket) => {
  const u = socket.user;
  if (!userSockets.has(u.id)) userSockets.set(u.id, new Set());
  userSockets.get(u.id).add(socket.id);
  const was = onlineUsers.has(u.id);
  onlineUsers.set(u.id, { socketId: socket.id, name: u.name, inCall: false });
  if (!was) broadcastPresence(u.id, true, false);

  socket.on("heartbeat", () => {
    const e = onlineUsers.get(u.id);
    if (e) e.socketId = socket.id;
    else { onlineUsers.set(u.id, { socketId: socket.id, name: u.name, inCall: false }); broadcastPresence(u.id, true, false); }
  });

  socket.on("call:offer", ({ toUserId, sdp }) => {
    const t = onlineUsers.get(toUserId);
    if (!t) return socket.emit("call:error", { toUserId, error: "对方不在线" });
    if (t.inCall) return socket.emit("call:error", { toUserId, error: "对方正忙" });
    if (onlineUsers.has(u.id)) onlineUsers.get(u.id).inCall = true;
    t.inCall = true;
    broadcastPresence(toUserId, true, true); broadcastPresence(u.id, true, true);
    io.to(t.socketId).emit("call:incoming", { fromUserId: u.id, fromName: u.name, sdp, autoAnswer: true });
  });

  socket.on("call:answer", ({ toUserId, sdp }) => {
    const t = onlineUsers.get(toUserId);
    if (t) io.to(t.socketId).emit("call:answered", { fromUserId: u.id, sdp, autoAnswer: true });
  });

  socket.on("call:ice", ({ toUserId, candidate }) => {
    const t = onlineUsers.get(toUserId);
    if (t) io.to(t.socketId).emit("call:ice", { fromUserId: u.id, candidate });
  });

  socket.on("call:end", ({ toUserId }) => {
    const t = onlineUsers.get(toUserId);
    if (t) { t.inCall = false; broadcastPresence(toUserId, true, false); io.to(t.socketId).emit("call:ended", { fromUserId: u.id }); }
    if (onlineUsers.has(u.id)) { onlineUsers.get(u.id).inCall = false; broadcastPresence(u.id, true, false); }
  });

  socket.on("remote:sharing", ({ viewerUserId, sdp }) => {
    const v = onlineUsers.get(viewerUserId);
    if (v) io.to(v.socketId).emit("remote:screen_offer", { fromUserId: u.id, fromName: u.name, sdp });
  });
  socket.on("remote:screen_answer", ({ fromUserId, sdp }) => {
    const t = onlineUsers.get(fromUserId);
    if (t) io.to(t.socketId).emit("remote:screen_answered", { sdp });
  });
  socket.on("remote:screen_ice", ({ toUserId, candidate }) => {
    const t = onlineUsers.get(toUserId);
    if (t) io.to(t.socketId).emit("remote:screen_ice", { candidate });
  });
  socket.on("remote:command", ({ toUserId, type, data }) => {
    const t = onlineUsers.get(toUserId);
    if (t) io.to(t.socketId).emit("remote:execute", { type, data, fromUserId: u.id });
    else socket.emit("remote:error", { error: "对方不在线" });
  });

  socket.on("disconnect", () => {
    const s = userSockets.get(u.id);
    if (s) { s.delete(socket.id); if (s.size > 0) return; userSockets.delete(u.id); }
    if (onlineUsers.get(u.id)?.inCall) io.emit("call:peer_disconnected", { userId: u.id });
    onlineUsers.delete(u.id);
    broadcastPresence(u.id, false, false);
  });
});

function broadcastPresence(uid, online, inCall) {
  dbAll("SELECT user_id FROM friends WHERE friend_id = ?", [uid]).forEach(r => {
    const s = userSockets.get(r.user_id);
    if (s) s.forEach(sid => io.to(sid).emit("presence", { userId: uid, online, inCall }));
  });
}

// ── 启动 ──
initDb().then(() => {
  server.listen(PORT, "0.0.0.0", () => {
    console.log("┌──────────────────────────────────────────┐");
    console.log(`│  EasyCall 一体化服务器                    │`);
    console.log(`│  http://localhost:${PORT}  → App 交互版    │`);
    console.log(`│  API: /api/login  /api/register  ...     │`);
    console.log("└──────────────────────────────────────────┘");
  });
});

