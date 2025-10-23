# CrewAI 快速开始指南

## ✅ CrewAI 完全支持你的所有需求

| 需求 | 支持情况 | 实现方式 |
|------|---------|---------|
| ✅ 章节/局势推进 | 完全支持 | Task 链 + 数据库状态 |
| ✅ 角色系统 | 完全支持 | Agent 管理 + 角色状态表 |
| ✅ 多结局 | 完全支持 | 结局生成 Agent |
| ✅ 断点续玩 | 完全支持 | 数据库持久化 |

## 一、安装依赖

```bash
pip install crewai crewai-tools supabase
```

## 二、数据库设置

### 方式 A：使用迁移文件（推荐）

```bash
# 使用迁移脚本
./supabase/apply-migration.sh

# 或手动执行
# 1. 打开 Supabase Dashboard -> SQL Editor
# 2. 复制 supabase/migrations/20250123_initial_schema.sql 的内容
# 3. 粘贴并执行
```

详见 [supabase/README.md](supabase/README.md)

### 方式 B：手动创建（快速测试）

在 Supabase SQL Editor 中执行以下 SQL：

```sql
-- 会话表
CREATE TABLE game_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES game_sessions(id),
  chapter INT,
  situation_id TEXT,
  situation_type TEXT,  -- 'main' | 'optional'
  score INT DEFAULT 0,
  target_score INT,
  status TEXT DEFAULT 'in_progress',  -- 'in_progress' | 'success' | 'failed'
  created_at TIMESTAMP DEFAULT NOW()
);

-- 角色状态表
CREATE TABLE character_states (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES game_sessions(id),
  character_name TEXT,
  status TEXT DEFAULT 'alive',  -- 'alive' | 'dead' | 'missing'
  attributes JSONB,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 对话历史表
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES game_sessions(id),
  chapter INT,
  role TEXT,
  content TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 结局记录表
CREATE TABLE endings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES game_sessions(id),
  ending_type TEXT,
  ending_content TEXT,
  situations_completed JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## 三、核心概念

### 1. 章节和局势

```python
# 章节配置示例
chapters = {
    1: {
        "title": "新君即位",
        "situations": {
            "eunuch_party": {  # 局势 ID
                "type": "main",  # 主要局势
                "name": "铲除阉党",
                "target_score": 100,  # 目标分数
                "description": "魏忠贤把持朝政，必须铲除"
            },
            "border_defense": {
                "type": "optional",  # 可选局势
                "name": "加强边防",
                "target_score": 80
            }
        }
    }
}
```

**局势推进逻辑**：
- 用户每次选择 → 局势分数变化（-50 到 +50）
- 分数 >= 目标分数 → 局势成功
- 分数 < 0 → 局势失败
- 所有主要局势完成 → 进入下一章节

### 2. 角色系统

```python
# 角色配置
characters = {
    "袁崇焕": {
        "background": "督师蓟辽，忠诚的边关大将",
        "personality": "忠诚、果断、直言",
        "initial_state": {
            "status": "alive",
            "loyalty": 95,
            "military_ability": 90
        }
    }
}
```

**角色状态变化**：
- 玩家选择影响角色属性（如 loyalty: 95 → 80）
- 角色可能死亡或失踪（status: alive → dead）
- 角色行为符合其性格背景

### 3. 多结局系统

```python
# 结局判定逻辑
if 成功局势 >= 80%:
    ending = "good_ending"  # 好结局
elif 成功局势 >= 50%:
    ending = "normal_ending"  # 普通结局
else:
    ending = "bad_ending"  # 坏结局
```

### 4. 断点续玩

```python
# 保存进度（自动）
await save_session_state(session_id, {
    "current_chapter": 2,
    "current_situation": "yuan_chonghuan",
    "situations": {...},
    "characters": {...}
})

# 恢复进度
session = await load_session(session_id)
# 从中断处继续
```

## 四、Agent 角色分工

CrewAI 使用多个 Agent 协作：

```python
# 1. 叙事者 - 生成剧情
narrator = Agent(
    role='故事叙事者',
    goal='生成生动的剧情描述'
)

# 2. 局势判定者 - 评估影响
situation_judge = Agent(
    role='局势判定者',
    goal='计算局势分数变化'
)

# 3. 角色管理者 - 更新角色
character_manager = Agent(
    role='角色管理者',
    goal='跟踪角色状态变化'
)

# 4. 章节协调者 - 控制推进
chapter_coordinator = Agent(
    role='章节协调者',
    goal='决定是否推进章节'
)

# 5. 结局生成者 - 生成结局
ending_generator = Agent(
    role='结局生成者',
    goal='根据表现生成结局'
)
```

## 五、完整流程

```
用户输入 "我要铲除魏忠贤"
    ↓
1. 叙事者生成剧情
   "你召集内阁大臣，下令彻查魏忠贤..."
    ↓
2. 局势判定者评估影响
   {score_change: +30, new_score: 30, status: "in_progress"}
    ↓
3. 角色管理者更新角色
   [{"character": "魏忠贤", "status": "dead"}]
    ↓
4. 章节协调者判断推进
   {action: "continue"}  # 继续当前章节
    ↓
5. 保存到数据库
    ↓
6. 返回给客户端
```

## 六、快速测试

```python
from crewai_story_agent import StoryAgentCrew

# 1. 创建 Agent
agent = StoryAgentCrew(
    supabase_url="your-supabase-url",
    supabase_key="your-supabase-key",
    story_id="chongzhen"
)

# 2. 创建新会话
session_id = await create_new_session(
    user_id="user_123",
    story_id="chongzhen"
)

# 3. 处理用户行动
result = await agent.process_user_action(
    session_id=session_id,
    user_input="我要铲除魏忠贤"
)

# 4. 查看结果
print("剧情：", result["story"])
print("局势：", result["situation_update"])
print("角色：", result["character_updates"])
print("状态：", result["chapter_status"])

# 5. 继续游戏（断点续玩）
result2 = await agent.process_user_action(
    session_id=session_id,  # 相同 session_id
    user_input="继续推进改革"
)
```

## 七、成本估算

使用 CrewAI + Replicate：

```
每次对话成本：
- 叙事者（Llama 3.1 70B）：$0.0027
- 判定者（Mistral 7B）：$0.0001
- 角色管理者（Mistral 7B）：$0.0001
- 章节协调者（Mistral 7B）：$0.0001
总计：约 $0.003/次

1000 次对话：$3
月成本（10 日活，每日 20 次）：$6
```

## 八、优势总结

### CrewAI 的优势

✅ **简单易用**：配置式开发，代码量少  
✅ **角色清晰**：每个 Agent 职责明确  
✅ **易于调试**：可以单独测试每个 Agent  
✅ **自动编排**：Task 链自动执行  
✅ **完美支持**：满足所有功能需求  

### 完整支持你的需求

1. **章节/局势推进** ✅
   - Task 链顺序执行
   - 数据库持久化状态
   - 自动判断推进时机

2. **角色系统** ✅
   - 角色管理者 Agent
   - 角色状态表
   - 性格背景一致性

3. **多结局** ✅
   - 结局生成 Agent
   - 根据完成局势判定
   - 自动生成结局内容

4. **断点续玩** ✅
   - 数据库自动保存
   - session_id 恢复进度
   - 无缝继续游戏

## 九、下一步

1. ✅ 查看完整实现：`agent-server/crewai_story_agent.py`
2. ✅ 配置数据库：执行上面的 SQL
3. ✅ 安装依赖：`pip install crewai supabase`
4. ✅ 测试运行：使用示例代码
5. ✅ 集成到 Flutter：调用 Agent API

需要我详细解释某个部分吗？
