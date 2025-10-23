# Flutter 后端集成说明

## ✅ 已完成的修改

### 修改内容

Flutter 应用已修改为调用 Python 后端（Agent Server），不再直接调用 Supabase。

#### 1. 会话创建
**之前**：直接调用 Supabase `chat_sessions` 表
```dart
await client.from('chat_sessions').insert({...})
```

**现在**：调用 Python 后端 API
```dart
POST http://localhost:8000/api/session/create
{
  "user_id": "user_xxx",
  "story_id": "chongzhen"
}
```

#### 2. 消息处理
**之前**：调用 Supabase Edge Function
```dart
POST https://xxx.supabase.co/functions/v1/edge-function-name
```

**现在**：调用 Python 后端 API
```dart
POST http://localhost:8000/api/story/action
{
  "session_id": "xxx",
  "user_input": "我要铲除魏忠贤"
}
```

## 🔧 配置

### 1. Flutter 环境变量

编辑 `app/.env`：

```env
# Supabase 配置（可选，如果不用可以留空）
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# Agent Server 配置（必需）
AGENT_SERVER_URL=http://localhost:8000

# iOS 模拟器使用本机 IP
# AGENT_SERVER_URL=http://192.168.1.100:8000

# Android 模拟器使用特殊 IP
# AGENT_SERVER_URL=http://10.0.2.2:8000
```

### 2. Agent Server 环境变量

编辑 `agent-server/.env`：

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
REPLICATE_API_TOKEN=your-replicate-token
REDIS_URL=redis://localhost:6379
```

## 🚀 测试流程

### 1. 启动 Agent Server

```bash
cd agent-server

# 确保 .env 已配置
cat .env

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f web

# 测试健康检查
curl http://localhost:8000/health
```

应该返回：
```json
{
  "status": "healthy",
  "redis": "healthy",
  "database": "healthy",
  "version": "2.0.0",
  "framework": "CrewAI"
}
```

### 2. 测试 API

```bash
# 创建会话
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user",
    "story_id": "chongzhen"
  }'

# 应该返回
{
  "session_id": "xxx-xxx-xxx",
  "story_id": "chongzhen",
  "current_chapter": 1,
  "current_situation": "eunuch_party",
  "message": "会话创建成功"
}

# 处理用户行动（使用上面返回的 session_id）
curl -X POST http://localhost:8000/api/story/action \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "xxx-xxx-xxx",
    "user_input": "我要铲除魏忠贤"
  }'

# 应该返回
{
  "story": "剧情描述...",
  "situation_update": {...},
  "character_updates": [...],
  "chapter_status": "continue"
}
```

### 3. 运行 Flutter 应用

```bash
cd app

# 确保 .env 已配置
cat .env

# 运行应用
flutter run

# 或指定设备
flutter run -d chrome      # Web
flutter run -d macos       # macOS
flutter run -d ios         # iOS 模拟器
flutter run -d android     # Android 模拟器
```

### 4. 测试游戏流程

1. **选择剧本**：点击"崇祯皇帝"
2. **查看详情**：点击"开始游戏"
3. **创建会话**：应该看到初始剧情
4. **输入行动**：输入"我要铲除魏忠贤"
5. **查看响应**：应该收到 AI 生成的剧情

### 5. 查看日志

#### Agent Server 日志
```bash
docker compose logs -f web
```

应该看到：
```
INFO: 172.29.0.19:xxx - "POST /api/session/create HTTP/1.1" 200 OK
INFO: 172.29.0.19:xxx - "POST /api/story/action HTTP/1.1" 200 OK
```

#### Flutter 日志
在终端查看 Flutter 输出：
```
会话已创建: xxx-xxx-xxx
```

## 🐛 故障排查

### 问题 1：无法连接到 Agent Server

**症状**：Flutter 显示"Agent Server 调用失败"

**检查**：
```bash
# 1. 确认 Agent Server 正在运行
curl http://localhost:8000/health

# 2. 检查 Flutter 的 .env 配置
cat app/.env | grep AGENT_SERVER_URL

# 3. iOS/Android 模拟器需要使用特殊 IP
# iOS: 本机 IP (ifconfig | grep "inet ")
# Android: 10.0.2.2
```

### 问题 2：数据库连接失败

**症状**：Agent Server 返回 "database unhealthy"

**解决**：
```bash
# 1. 检查 Supabase 配置
docker compose exec web env | grep SUPABASE

# 2. 确认使用 service_role key（不是 anon key）
echo $SUPABASE_SERVICE_ROLE_KEY | base64 -d
# 应该包含 "role":"service_role"

# 3. 重启服务
docker compose restart web
```

### 问题 3：会话创建失败

**症状**：返回 404 或 500 错误

**检查**：
```bash
# 1. 确认数据库表已创建
# 在 Supabase Dashboard -> Table Editor 查看

# 2. 测试 API
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "story_id": "chongzhen"}'

# 3. 查看详细错误
docker compose logs --tail=50 web
```

### 问题 4：剧情生成失败

**症状**：收到空响应或错误

**检查**：
```bash
# 1. 确认 Replicate API Token 已配置
docker compose exec web env | grep REPLICATE

# 2. 测试 Replicate 连接
curl https://api.replicate.com/v1/models \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN"

# 3. 查看 Agent 日志
docker compose logs --tail=100 web | grep -i error
```

## 📊 数据流

```
Flutter App
    ↓
    POST /api/session/create
    ↓
Agent Server (FastAPI)
    ↓
    创建 game_sessions 记录
    ↓
Supabase (PostgreSQL)
    ↓
    返回 session_id
    ↓
Flutter App

---

Flutter App
    ↓
    POST /api/story/action
    {session_id, user_input}
    ↓
Agent Server (FastAPI)
    ↓
    CrewAI Agents 处理
    ↓
    - 叙事者生成剧情
    - 判定者评估局势
    - 角色管理者更新状态
    - 章节协调者检查进度
    ↓
    更新数据库
    ↓
Supabase (PostgreSQL)
    ↓
    返回剧情和状态
    ↓
Flutter App
```

## ✅ 验证清单

- [ ] Agent Server 健康检查通过
- [ ] 数据库连接正常（database: healthy）
- [ ] 可以创建会话
- [ ] 可以处理用户行动
- [ ] Flutter 可以连接到 Agent Server
- [ ] 游戏流程正常运行
- [ ] 剧情生成正常

## 📝 下一步

1. ✅ 完善错误处理
2. ✅ 添加加载状态
3. ✅ 优化 UI 显示
4. ✅ 添加重试机制
5. ✅ 实现断点续玩

完成！🎉
