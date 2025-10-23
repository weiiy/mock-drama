# Supabase Schema Cache 问题修复

## 错误信息

```
Could not find the 'chapter' column of 'situation_states' in the schema cache
```

## 原因

Supabase 的 PostgREST API 缓存了旧的数据库 schema，需要刷新。

## 解决方案

### 方案 1：Dashboard 重启（推荐）

1. **打开 Supabase Dashboard**
   ```
   https://app.supabase.com/project/your-project-id/settings/api
   ```

2. **找到 "Restart PostgREST"**
   - 在 API Settings 页面
   - 点击 "Restart" 按钮
   - 等待 10-30 秒

3. **测试**
   ```bash
   curl http://localhost:8000/health
   ```

### 方案 2：SQL 刷新（快速）

在 Supabase SQL Editor 中执行：

```sql
-- 刷新 schema cache
NOTIFY pgrst, 'reload schema';
```

然后重启 Agent Server：
```bash
docker compose restart web
```

### 方案 3：完全重置（如果上面都不行）

⚠️ **警告：会删除所有数据！**

在 Supabase SQL Editor 中执行 `reset-and-recreate.sql`：

```bash
# 复制文件内容
cat supabase/reset-and-recreate.sql

# 在 Supabase SQL Editor 中粘贴并执行
```

## 验证

### 1. 检查表结构

```sql
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'situation_states'
ORDER BY ordinal_position;
```

应该看到 `chapter` 列。

### 2. 测试 API

```bash
# 测试健康检查
curl http://localhost:8000/health

# 应该返回
{
  "status": "healthy",
  "database": "healthy"  # ✅
}

# 测试创建会话
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "story_id": "chongzhen"}'

# 应该成功返回 session_id
```

### 3. 测试 Flutter

```bash
# 重新运行 Flutter
flutter run

# 应该看到
flutter: 会话已创建: xxx-xxx-xxx
```

## 常见问题

### Q: 为什么会出现这个问题？

A: 当你修改数据库表结构后，Supabase 的 PostgREST API 可能还在使用旧的 schema 缓存。

### Q: 多久刷新一次？

A: 通常 Supabase 会自动检测变化，但有时需要手动刷新。

### Q: 会影响生产环境吗？

A: 重启 PostgREST 会有几秒钟的中断，建议在低峰期操作。

## 预防措施

### 1. 使用迁移文件

始终使用迁移文件而不是手动修改表：
```sql
-- 好的做法
CREATE TABLE IF NOT EXISTS ...

-- 避免
ALTER TABLE ... ADD COLUMN ...
```

### 2. 执行后刷新

每次修改 schema 后立即刷新：
```sql
-- 你的 DDL 语句
CREATE TABLE ...

-- 刷新
NOTIFY pgrst, 'reload schema';
```

### 3. 使用 Supabase CLI

```bash
# 推送迁移会自动刷新
supabase db push
```

## 完整流程

```bash
# 1. 在 Supabase SQL Editor 执行
NOTIFY pgrst, 'reload schema';

# 2. 重启 Agent Server
cd agent-server
docker compose restart web

# 3. 测试
curl http://localhost:8000/health

# 4. 运行 Flutter
cd app
flutter run

# 5. 测试游戏
# - 选择剧本
# - 开始游戏
# - 输入行动
# - 应该正常工作 ✅
```

## 如果还是不行

1. **完全重置数据库**
   ```sql
   -- 执行 reset-and-recreate.sql
   ```

2. **清理 Agent Server 缓存**
   ```bash
   docker compose down
   docker system prune -f
   docker compose up -d --build
   ```

3. **重启 Flutter**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

完成！🎉
