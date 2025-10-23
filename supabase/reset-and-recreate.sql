-- 完全重置并重新创建表
-- ⚠️ 警告：会删除所有数据！

-- 1. 删除所有表
DROP TABLE IF EXISTS endings CASCADE;
DROP TABLE IF EXISTS character_states CASCADE;
DROP TABLE IF EXISTS situation_states CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP FUNCTION IF EXISTS update_updated_at CASCADE;

-- 2. 重新创建表
CREATE TABLE game_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    story_id TEXT NOT NULL,
    current_chapter INTEGER DEFAULT 1,
    current_situation TEXT,
    is_completed BOOLEAN DEFAULT FALSE,
    ending_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
    chapter INTEGER DEFAULT 1,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE situation_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
    chapter INTEGER NOT NULL,
    situation_id TEXT NOT NULL,
    situation_type TEXT CHECK (situation_type IN ('main', 'optional')),
    score INTEGER DEFAULT 0,
    target_score INTEGER NOT NULL,
    status TEXT CHECK (status IN ('in_progress', 'completed', 'failed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, situation_id)
);

CREATE TABLE character_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
    character_name TEXT NOT NULL,
    status TEXT CHECK (status IN ('alive', 'dead', 'missing', 'imprisoned')),
    attributes JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, character_name)
);

CREATE TABLE endings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
    ending_type TEXT NOT NULL,
    ending_content TEXT NOT NULL,
    situations_completed JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 创建索引
CREATE INDEX idx_game_sessions_user_id ON game_sessions(user_id);
CREATE INDEX idx_chat_messages_session_id ON chat_messages(session_id);
CREATE INDEX idx_situation_states_session_id ON situation_states(session_id);
CREATE INDEX idx_character_states_session_id ON character_states(session_id);
CREATE INDEX idx_endings_session_id ON endings(session_id);

-- 4. 创建触发器
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_game_sessions_updated_at
    BEFORE UPDATE ON game_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_situation_states_updated_at
    BEFORE UPDATE ON situation_states
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_character_states_updated_at
    BEFORE UPDATE ON character_states
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 5. 刷新 schema cache
NOTIFY pgrst, 'reload schema';

-- 6. 验证
SELECT 'Tables recreated successfully!' as status;
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
