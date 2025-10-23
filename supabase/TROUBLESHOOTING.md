# SQL 迁移故障排查

## 错误：column "chapter" does not exist

### 问题描述
执行迁移时报错：`ERROR: 42703: column "chapter" does not exist`

### 原因分析
可能的原因：
1. 表还未创建就引用了列
2. 之前执行失败，表结构不完整
3. 执行顺序错误

### 解决方案

#### 方案 1：分段执行（推荐）

按顺序执行以下文件：

```sql
-- 1. 创建表
-- 执行: migrations/20250123_01_tables.sql

-- 2. 创建索引
-- 执行: migrations/20250123_02_indexes.sql

-- 3. 创建触发器和 RLS（可选）
-- 执行: migrations/20250123_initial_schema.sql 的第 6-7 节
```

#### 方案 2：清理后重新执行

```sql
-- 1. 删除所有表（⚠️ 会删除数据）
DROP TABLE IF EXISTS endings CASCADE;
DROP TABLE IF EXISTS character_states CASCADE;
DROP TABLE IF EXISTS situation_states CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF NOT EXISTS game_sessions CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;

-- 2. 重新执行完整迁移
-- 执行: migrations/20250123_initial_schema.sql
```

#### 方案 3：检查表结构

```sql
-- 检查 chat_messages 表是否存在
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'chat_messages';

-- 如果表存在但缺少 chapter 列，添加它
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS chapter INTEGER NOT NULL DEFAULT 1;
```

---

## 其他常见错误

### 错误：relation already exists

**问题**：表已存在

**解决**：
```sql
-- 使用 IF NOT EXISTS
CREATE TABLE IF NOT EXISTS table_name (...);

-- 或先删除
DROP TABLE IF EXISTS table_name CASCADE;
```

### 错误：permission denied

**问题**：权限不足

**解决**：
- 确保使用 `service_role` key
- 或在 Supabase Dashboard 的 SQL Editor 中执行（自动使用管理员权限）

### 错误：syntax error

**问题**：SQL 语法错误

**解决**：
```bash
# 运行测试脚本检查语法
./supabase/test-migration.sh
```

---

## 验证迁移

### 检查表是否创建

```sql
-- 查看所有表
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';

-- 应该看到：
-- game_sessions
-- chat_messages
-- situation_states
-- character_states
-- endings
```

### 检查列是否存在

```sql
-- 查看 chat_messages 的所有列
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'chat_messages'
ORDER BY ordinal_position;

-- 应该包含：
-- id, session_id, chapter, role, content, created_at
```

### 检查索引

```sql
-- 查看所有索引
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

### 检查 RLS 策略

```sql
-- 查看 RLS 状态
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';

-- 查看策略
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public';
```

---

## 完全重置（⚠️ 危险）

如果需要完全重置数据库：

```sql
-- 删除所有表
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- 恢复默认权限
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- 重新执行迁移
-- ...
```

---

## 获取帮助

1. **查看错误详情**
   - 记录完整的错误消息
   - 记录错误发生的行号

2. **检查 Supabase 日志**
   - Dashboard → Logs → Postgres Logs

3. **测试 SQL**
   ```bash
   ./supabase/test-migration.sh
   ```

4. **分段执行**
   - 先执行表创建
   - 再执行索引
   - 最后执行 RLS

---

## 快速修复脚本

```bash
#!/bin/bash
# fix-migration.sh

echo "🔧 修复数据库迁移"

# 1. 删除所有表
echo "1️⃣ 清理旧表..."
psql $DATABASE_URL << EOF
DROP TABLE IF EXISTS endings CASCADE;
DROP TABLE IF EXISTS character_states CASCADE;
DROP TABLE IF EXISTS situation_states CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;
EOF

# 2. 创建表
echo "2️⃣ 创建表..."
psql $DATABASE_URL < migrations/20250123_01_tables.sql

# 3. 创建索引
echo "3️⃣ 创建索引..."
psql $DATABASE_URL < migrations/20250123_02_indexes.sql

echo "✅ 完成！"
```

---

## 联系支持

如果问题仍未解决：
1. 检查 [Supabase 文档](https://supabase.com/docs)
2. 查看 [GitHub Issues](https://github.com/supabase/supabase/issues)
3. 加入 [Discord 社区](https://discord.supabase.com/)
