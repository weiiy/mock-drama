# Supabase 数据库迁移

## 目录结构

```
supabase/
├── migrations/
│   └── 20250123_initial_schema.sql  # 初始数据库结构
└── README.md                         # 本文件
```

## 使用方法

### 方式 1：Supabase CLI（推荐）

#### 1. 安装 Supabase CLI

```bash
# Mac
brew install supabase/tap/supabase

# Linux/WSL
curl -fsSL https://raw.githubusercontent.com/supabase/cli/main/install.sh | sh

# Windows
scoop install supabase
```

#### 2. 登录 Supabase

```bash
supabase login
```

#### 3. 链接到项目

```bash
# 在项目根目录
cd mock-drama

# 链接到你的 Supabase 项目
supabase link --project-ref your-project-ref

# project-ref 可以在 Supabase Dashboard URL 中找到
# 例如：https://app.supabase.com/project/pxgqaijnwbhuumhivclr
# project-ref 就是 pxgqaijnwbhuumhivclr
```

#### 4. 运行迁移

```bash
# 推送迁移到远程数据库
supabase db push

# 或者应用所有迁移
supabase migration up
```

#### 5. 验证

```bash
# 查看迁移状态
supabase migration list

# 查看数据库结构
supabase db diff
```

---

### 方式 2：Supabase Dashboard（手动）

#### 1. 打开 SQL Editor

1. 登录 [Supabase Dashboard](https://app.supabase.com/)
2. 选择你的项目
3. 点击左侧菜单的 **SQL Editor**

#### 2. 执行迁移

1. 点击 **New Query**
2. 复制 `migrations/20250123_initial_schema.sql` 的内容
3. 粘贴到编辑器
4. 点击 **Run** 执行

#### 3. 验证

在 **Table Editor** 中查看是否创建了以下表：
- ✅ `game_sessions`
- ✅ `chat_messages`
- ✅ `situation_states`
- ✅ `character_states`
- ✅ `endings`

---

## 数据库结构

### 1. game_sessions（游戏会话）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | TEXT | 用户ID |
| story_id | TEXT | 剧本ID |
| current_chapter | INTEGER | 当前章节 |
| current_situation | TEXT | 当前局势ID |
| is_completed | BOOLEAN | 是否完成 |
| ending_type | TEXT | 结局类型 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 2. chat_messages（聊天消息）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| session_id | UUID | 会话ID（外键） |
| chapter | INTEGER | 章节 |
| role | TEXT | 角色（user/assistant/system） |
| content | TEXT | 消息内容 |
| created_at | TIMESTAMP | 创建时间 |

### 3. situation_states（局势状态）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| session_id | UUID | 会话ID（外键） |
| chapter | INTEGER | 章节 |
| situation_id | TEXT | 局势ID |
| situation_type | TEXT | 类型（main/optional） |
| score | INTEGER | 当前分数 |
| target_score | INTEGER | 目标分数 |
| status | TEXT | 状态（in_progress/completed/failed） |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 4. character_states（角色状态）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| session_id | UUID | 会话ID（外键） |
| character_name | TEXT | 角色名称 |
| status | TEXT | 状态（alive/dead/missing/imprisoned） |
| attributes | JSONB | 角色属性（JSON） |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 5. endings（结局）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| session_id | UUID | 会话ID（外键） |
| ending_type | TEXT | 结局类型 |
| ending_content | TEXT | 结局内容 |
| situations_completed | JSONB | 完成的局势（JSON） |
| created_at | TIMESTAMP | 创建时间 |

---

## RLS (Row Level Security)

所有表都启用了 RLS，确保用户只能访问自己的数据。

### 策略说明

- **用户访问**：用户只能查看和修改自己的会话数据
- **Service Role**：使用 `service_role` key 可以绕过 RLS（用于 Agent Server）

### 测试 RLS

```sql
-- 以普通用户身份查询（会受到 RLS 限制）
SELECT * FROM game_sessions;

-- 使用 service_role key 查询（绕过 RLS）
-- 在 Agent Server 中自动使用
```

---

## 创建新迁移

### 1. 使用 Supabase CLI

```bash
# 创建新迁移文件
supabase migration new add_new_feature

# 编辑生成的文件
# supabase/migrations/20250123123456_add_new_feature.sql

# 应用迁移
supabase db push
```

### 2. 手动创建

1. 在 `migrations/` 目录创建新文件
2. 命名格式：`YYYYMMDD_description.sql`
3. 编写 SQL
4. 在 Supabase Dashboard 执行

---

## 回滚迁移

### 使用 Supabase CLI

```bash
# 查看迁移历史
supabase migration list

# 回滚到指定版本
supabase db reset --version 20250123000000
```

### 手动回滚

创建反向迁移文件：

```sql
-- migrations/20250123_rollback_initial.sql
DROP TABLE IF EXISTS endings CASCADE;
DROP TABLE IF EXISTS character_states CASCADE;
DROP TABLE IF EXISTS situation_states CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;
```

---

## 常见问题

### 1. 迁移失败

**问题**：执行迁移时报错

**解决**：
```bash
# 查看详细错误
supabase db push --debug

# 重置数据库（⚠️ 会删除所有数据）
supabase db reset
```

### 2. RLS 阻止访问

**问题**：Agent Server 无法访问数据库

**解决**：
- 确保使用 `service_role` key（不是 `anon` key）
- Service role key 可以绕过 RLS

### 3. 表已存在

**问题**：`table already exists`

**解决**：
```sql
-- 使用 IF NOT EXISTS
CREATE TABLE IF NOT EXISTS table_name (...);

-- 或先删除表
DROP TABLE IF EXISTS table_name CASCADE;
```

---

## 备份和恢复

### 备份

```bash
# 使用 Supabase CLI
supabase db dump -f backup.sql

# 或使用 pg_dump
pg_dump -h db.your-project.supabase.co \
  -U postgres \
  -d postgres \
  -f backup.sql
```

### 恢复

```bash
# 使用 Supabase CLI
supabase db reset
supabase db push

# 或使用 psql
psql -h db.your-project.supabase.co \
  -U postgres \
  -d postgres \
  -f backup.sql
```

---

## 下一步

1. ✅ 执行迁移创建数据库表
2. ✅ 获取 `service_role` key
3. ✅ 更新 `agent-server/.env`
4. ✅ 重启 Agent Server
5. ✅ 测试 API

---

## 相关文档

- [Supabase CLI 文档](https://supabase.com/docs/guides/cli)
- [数据库迁移指南](https://supabase.com/docs/guides/database/migrations)
- [RLS 策略](https://supabase.com/docs/guides/auth/row-level-security)
