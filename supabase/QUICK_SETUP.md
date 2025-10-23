# 快速数据库设置

## 🚀 一键执行

### 步骤

1. **打开 Supabase SQL Editor**
   ```
   https://app.supabase.com/project/your-project-id/sql
   ```

2. **复制 SQL**
   ```bash
   cat supabase/migrations/simple_schema.sql
   ```

3. **粘贴并执行**
   - 点击 "New Query"
   - 粘贴 `simple_schema.sql` 的全部内容
   - 点击 "Run" 或按 `Cmd/Ctrl + Enter`

4. **验证**
   - 进入 "Table Editor"
   - 应该看到 5 个表：
     - ✅ game_sessions
     - ✅ chat_messages
     - ✅ situation_states
     - ✅ character_states
     - ✅ endings

## 📊 表结构说明

### 核心表（5个）

| 表名 | 用途 | 关键字段 |
|------|------|---------|
| **game_sessions** | 游戏会话 | user_id, story_id, current_chapter |
| **chat_messages** | 对话历史 | session_id, role, content |
| **situation_states** | 局势状态 | session_id, situation_id, score |
| **character_states** | 角色状态 | session_id, character_name, status |
| **endings** | 结局记录 | session_id, ending_type |

### 特性

✅ **外键约束**：自动级联删除  
✅ **索引优化**：提升查询性能  
✅ **自动更新时间**：updated_at 字段自动更新  
✅ **数据验证**：CHECK 约束确保数据有效性  

## 🔑 获取 Service Role Key

执行 SQL 后，获取 API Key：

1. **进入 Settings → API**
2. **复制 `service_role` key**（不是 anon key！）
3. **更新 agent-server/.env**
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
4. **重启服务**
   ```bash
   cd agent-server
   docker compose restart web
   ```

## ✅ 验证

### 1. 检查健康状态

```bash
curl http://localhost:8000/health
```

应该返回：
```json
{
  "status": "healthy",
  "redis": "healthy",
  "database": "healthy",  // ✅ 这里应该是 healthy
  "version": "2.0.0",
  "framework": "CrewAI"
}
```

### 2. 测试创建会话

```bash
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user",
    "story_id": "chongzhen"
  }'
```

应该返回会话信息。

## 🔧 如果需要重置

```sql
-- 删除所有表
DROP TABLE IF EXISTS endings CASCADE;
DROP TABLE IF EXISTS character_states CASCADE;
DROP TABLE IF EXISTS situation_states CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP FUNCTION IF EXISTS update_updated_at CASCADE;

-- 然后重新执行 simple_schema.sql
```

## 📝 与之前版本的区别

### 精简版 (simple_schema.sql)
- ✅ 只包含核心 5 个表
- ✅ 移除了 RLS（使用 service_role key 绕过）
- ✅ 精简的索引（只保留必要的）
- ✅ 更简洁的语法

### 完整版 (20250123_initial_schema.sql)
- 包含详细注释
- 完整的索引
- RLS 策略
- 更多验证规则

**推荐**：先使用精简版快速测试，生产环境再考虑完整版。

## 🎯 下一步

1. ✅ 执行 `simple_schema.sql`
2. ✅ 获取 service_role key
3. ✅ 更新 `.env`
4. ✅ 重启服务
5. ✅ 测试 API
6. ✅ 开始开发！

完成！🎉
