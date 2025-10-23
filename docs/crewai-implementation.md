# CrewAI 实现方案 - 完整功能支持

## 功能需求分析

### ✅ CrewAI 可以完美支持所有需求

| 需求 | CrewAI 支持 | 实现方式 |
|------|------------|---------|
| 章节/局势推进 | ✅ | 使用 Task 链式执行 + 自定义状态管理 |
| 角色系统 | ✅ | 每个角色定义为独立 Agent |
| 多结局系统 | ✅ | 条件判断 + 结局生成 Agent |
| 断点续玩 | ✅ | 数据库持久化 + 状态恢复 |

## 一、架构设计

### Agent 角色分工

```python
from crewai import Agent, Task, Crew, Process

# 1. 叙事者 Agent - 生成剧情
narrator = Agent(
    role='故事叙事者',
    goal='根据玩家选择和当前局势生成生动的剧情',
    backstory='你是一位经验丰富的历史小说家，擅长描绘明朝历史',
    llm='meta/meta-llama-3.1-70b-instruct'  # Replicate
)

# 2. 局势判定者 Agent - 评估局势进展
situation_judge = Agent(
    role='局势判定者',
    goal='评估玩家决策对当前局势的影响，计算局势分数',
    backstory='你是一位严谨的历史学家，能准确评估政治决策的影响',
    llm='mistralai/mistral-7b-instruct-v0.2'  # 便宜的判定模型
)

# 3. 角色管理者 Agent - 管理角色状态
character_manager = Agent(
    role='角色管理者',
    goal='跟踪和更新剧本中所有角色的状态',
    backstory='你负责维护角色的一致性和状态变化',
    llm='mistralai/mistral-7b-instruct-v0.2'
)

# 4. 章节协调者 Agent - 决定章节推进
chapter_coordinator = Agent(
    role='章节协调者',
    goal='根据局势完成情况决定是否推进到下一章节',
    backstory='你是游戏设计师，负责控制剧情节奏',
    llm='mistralai/mistral-7b-instruct-v0.2'
)

# 5. 结局生成者 Agent - 生成结局
ending_generator = Agent(
    role='结局生成者',
    goal='根据玩家完成的局势生成相应的结局',
    backstory='你是结局设计师，能根据玩家表现生成不同结局',
    llm='meta/meta-llama-3.1-70b-instruct'
)
```

### 数据库设计

```sql
-- 会话表
CREATE TABLE game_sessions (
  id UUID PRIMARY KEY,
  user_id UUID,
  story_id TEXT,
  current_chapter INT DEFAULT 1,
  current_situation TEXT,
  is_completed BOOLEAN DEFAULT FALSE,
  ending_type TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 局势状态表
CREATE TABLE situation_states (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES game_sessions(id),
  chapter INT,
  situation_id TEXT,
  situation_type TEXT,  -- 'main' | 'optional'
  score INT DEFAULT 0,
  target_score INT,
  status TEXT,  -- 'in_progress' | 'success' | 'failed'
  created_at TIMESTAMP DEFAULT NOW()
);

-- 角色状态表
CREATE TABLE character_states (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES game_sessions(id),
  character_name TEXT,
  status TEXT,  -- 'alive' | 'dead' | 'missing'
  attributes JSONB,  -- {loyalty: 80, power: 50}
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 对话历史表
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES game_sessions(id),
  chapter INT,
  role TEXT,
  content TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 结局记录表
CREATE TABLE endings (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES game_sessions(id),
  ending_type TEXT,
  ending_content TEXT,
  situations_completed JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## 二、完整实现代码

见 `agent-server/crewai_story_agent.py`
