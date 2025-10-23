# 数据库设置指南

## 📁 迁移文件位置

```
supabase/
├── migrations/
│   └── 20250123_initial_schema.sql  # 完整的数据库结构
├── apply-migration.sh                # 自动执行脚本
└── README.md                         # 详细文档
```

## 🚀 快速开始

### 方式 1：使用 Supabase CLI（推荐）

```bash
# 1. 安装 Supabase CLI
brew install supabase/tap/supabase  # Mac
# 或参考 supabase/README.md 其他平台

# 2. 执行迁移脚本
./supabase/apply-migration.sh

# 3. 按提示操作
# - 登录 Supabase
# - 输入 Project Ref
# - 确认执行迁移
```

### 方式 2：手动执行（简单快速）

```bash
# 1. 打开 Supabase Dashboard
open https://app.supabase.com/

# 2. 选择你的项目

# 3. 进入 SQL Editor

# 4. 复制迁移文件内容
cat supabase/migrations/20250123_initial_schema.sql

# 5. 粘贴到 SQL Editor 并执行
```

## 📊 创建的表

执行迁移后会创建以下表：

### 1. game_sessions（游戏会话）
- 记录每个玩家的游戏进度
- 包含：会话ID、用户ID、剧本ID、当前章节、当前局势、是否完成、结局类型

### 2. chat_messages（聊天消息）
- 记录玩家与 AI 的对话历史
- 包含：消息ID、会话ID、章节、角色、内容

### 3. situation_states（局势状态）
- 记录每个会话的局势进度
- 包含：局势ID、会话ID、章节、类型、分数、目标分数、状态

### 4. character_states（角色状态）
- 记录每个会话中角色的状态
- 包含：角色ID、会话ID、角色名称、状态、属性（JSON）

### 5. endings（结局）
- 记录玩家达成的结局
- 包含：结局ID、会话ID、结局类型、结局内容、完成的局势

## 🔐 获取 Service Role Key

迁移完成后，需要获取 `service_role` key：

### 步骤

1. **打开 Supabase Dashboard**
   ```
   https://app.supabase.com/project/your-project-id
   ```

2. **进入 Settings → API**

3. **找到 Project API keys**

4. **复制 `service_role` key**（不是 `anon` key！）
   - `anon` key: 客户端使用，权限受限
   - `service_role` key: 服务端使用，完全权限

5. **更新 `.env` 文件**
   ```bash
   cd agent-server
   nano .env
   
   # 更新这一行
   SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   # 注意：应该包含 "role":"service_role"
   ```

6. **重启服务**
   ```bash
   docker compose restart web
   ```

## ✅ 验证

### 1. 检查表是否创建

在 Supabase Dashboard → Table Editor 中应该看到：
- ✅ game_sessions
- ✅ chat_messages
- ✅ situation_states
- ✅ character_states
- ✅ endings

### 2. 测试 Agent Server

```bash
# 健康检查
curl http://localhost:8000/health

# 应该返回
{
  "status": "healthy",
  "redis": "healthy",
  "database": "healthy",  # ✅ 这里应该是 healthy
  "version": "2.0.0",
  "framework": "CrewAI"
}
```

### 3. 测试创建会话

```bash
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user",
    "story_id": "chongzhen"
  }'

# 应该返回会话信息
{
  "session_id": "...",
  "story_id": "chongzhen",
  "current_chapter": 1,
  "current_situation": "eunuch_party",
  "message": "会话创建成功"
}
```

## 🔧 故障排查

### 问题 1：数据库显示 unhealthy

**原因**：
- 使用了 `anon` key 而不是 `service_role` key
- 环境变量未正确设置

**解决**：
```bash
# 1. 检查环境变量
docker compose exec web env | grep SUPABASE

# 2. 确认是 service_role key（包含 "role":"service_role"）
echo $SUPABASE_SERVICE_ROLE_KEY | base64 -d

# 3. 如果不对，更新 .env 并重启
docker compose restart web
```

### 问题 2：表已存在

**原因**：之前手动创建过表

**解决**：
```sql
-- 在 Supabase SQL Editor 中删除旧表
DROP TABLE IF EXISTS endings CASCADE;
DROP TABLE IF EXISTS character_states CASCADE;
DROP TABLE IF EXISTS situation_states CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;

-- 然后重新执行迁移
```

### 问题 3：RLS 阻止访问

**原因**：使用了 `anon` key

**解决**：
- 确保使用 `service_role` key
- Service role key 可以绕过 RLS 策略

## 📚 相关文档

- **迁移详细说明**：[supabase/README.md](supabase/README.md)
- **快速开始**：[QUICKSTART_CREWAI.md](QUICKSTART_CREWAI.md)
- **部署指南**：[DEPLOYMENT.md](DEPLOYMENT.md)
- **Docker 使用**：[agent-server/DOCKER_USAGE.md](agent-server/DOCKER_USAGE.md)

## 🎯 完整流程

```bash
# 1. 执行数据库迁移
./supabase/apply-migration.sh

# 2. 获取 service_role key
# 在 Supabase Dashboard -> Settings -> API

# 3. 更新 .env
cd agent-server
nano .env
# 填写 SUPABASE_URL 和 SUPABASE_SERVICE_ROLE_KEY

# 4. 重启服务
docker compose restart web

# 5. 测试
curl http://localhost:8000/health

# 6. 创建会话测试
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "story_id": "chongzhen"}'
```

## ✨ 完成！

数据库设置完成后，你可以：
1. ✅ 使用 Agent Server API
2. ✅ 集成到 Flutter 应用
3. ✅ 开始游戏开发

祝开发顺利！🚀
