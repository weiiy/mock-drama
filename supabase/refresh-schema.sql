-- 刷新 Supabase Schema Cache
-- 在 Supabase SQL Editor 中执行

-- 方法 1: 通知 PostgREST 重新加载 schema
NOTIFY pgrst, 'reload schema';

-- 方法 2: 如果方法 1 不起作用，重新加载配置
SELECT pg_reload_conf();

-- 验证表是否存在
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('game_sessions', 'chat_messages', 'situation_states', 'character_states', 'endings')
ORDER BY table_name, ordinal_position;
