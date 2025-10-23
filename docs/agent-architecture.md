# Agent 架构设计文档

## 为什么需要 Agent？

单纯的大模型**无法完成**互动剧本的任务，原因如下：

### 大模型的局限性
1. **无状态管理**：不知道当前在哪个章节、局势如何
2. **无判定能力**：不知道什么时候该推进剧情、结束章节
3. **无数据库操作**：无法自主写入状态、更新进度
4. **无分支逻辑**：无法处理复杂的条件判断和状态变量

### Agent 的作用
Agent 是一个**协调器**，它：
- 管理剧本状态（通过 ink）
- 调用大模型生成内容
- 判定剧情进展
- 操作数据库
- 协调多个组件

## 架构组件

```
┌─────────────────────────────────────────────────────────────┐
│                      Agent 协调器                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ ink 引擎 │  │ 记忆系统 │  │ 大模型   │  │ 判定器   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
    剧本结构        历史上下文      剧情生成      进度判定
```

### 1. ink 引擎（剧本骨架）

**作用**：定义剧本结构，不生成具体内容

```ink
// chongzhen.ink
=== chapter_1 ===
# chapter:1
# situation:initial

VAR ming_years = 0
VAR treasury = 100
VAR army_morale = 50
VAR rebellion_threat = 80

// 这里只定义结构，不写具体剧情
// 具体剧情由大模型生成

* [整顿吏治]
    ~ treasury -= 20
    ~ ming_years += 2
    -> reform_path
    
* [增强军备]
    ~ treasury -= 30
    ~ army_morale += 15
    ~ rebellion_threat -= 10
    -> military_path

=== reform_path ===
# situation:reform
// 大模型会根据这个标签生成对应剧情
-> check_chapter_end

=== military_path ===
# situation:military
-> check_chapter_end

=== check_chapter_end ===
// 根据状态变量判断是否进入下一章节
{ 
    - ming_years >= 10:
        -> chapter_2
    - rebellion_threat <= 30:
        -> chapter_2
    - else:
        -> chapter_1
}

=== chapter_2 ===
# chapter:2
# situation:expansion
// 第二章开始
```

### 2. 记忆系统（上下文管理）

**短期记忆**：最近 10 轮对话
```typescript
conversationHistory: [
  { role: "user", content: "我要整顿吏治" },
  { role: "assistant", content: "你下令..." },
  // ...
]
```

**长期记忆**：向量检索历史事件
```sql
-- memory_records 表
CREATE TABLE memory_records (
  id UUID PRIMARY KEY,
  session_id UUID,
  chapter INT,
  summary TEXT,  -- "玩家在第一章选择了整顿吏治，损失20库银，获得2年续命"
  embedding VECTOR(1536),  -- 向量嵌入
  importance FLOAT,  -- 重要性评分
  created_at TIMESTAMP
);
```

### 3. 大模型（内容生成）

**输入**：
- ink 当前状态（章节、局势、变量）
- 记忆上下文
- 用户输入

**输出**：
- 生动的剧情描述

```typescript
const systemPrompt = `
你是崇祯皇帝剧本的叙事者。

当前状态：
- 章节：第${chapter}章
- 局势：${situation}
- 库银：${treasury}
- 军队士气：${army_morale}

历史事件：
${memories.join('\n')}

请根据玩家的选择"${userInput}"，生成生动的剧情描述。
`;
```

### 4. 判定器（进度控制）

**作用**：决定什么时候推进剧情

```typescript
// 判定提示词
const judgmentPrompt = `
根据以下信息判断：

当前章节：${chapter}
局势：${situation}
状态变量：${JSON.stringify(variables)}
最新剧情：${llmResponse}

判断：
1. 当前局势完成度（0-100）
2. 是否进入下一章节
3. 是否结束故事

返回 JSON：
{
  "situationScore": 85,
  "shouldAdvanceChapter": true,
  "shouldEndStory": false,
  "rationale": "玩家成功解决边疆危机",
  "stateChanges": {
    "ming_years": 3,
    "treasury": -50
  }
}
`;
```

## 完整流程示例

### 用户输入："我要整顿吏治"

```typescript
// 1. Agent 接收输入
const userInput = "我要整顿吏治";

// 2. 查询 ink 引擎
const inkState = await inkRuntime.getState({
  storyId: "chongzhen",
  chapter: 1,
  variables: { treasury: 100, ming_years: 0 }
});
// 返回：
// {
//   currentText: "",  // ink 不生成具体文本
//   choices: [
//     { index: 0, text: "整顿吏治" },
//     { index: 1, text: "增强军备" }
//   ],
//   tags: { chapter: 1, situation: "initial" },
//   variables: { treasury: 100, ming_years: 0, ... }
// }

// 3. 用户选择了 choice 0，推进 ink
await inkRuntime.choose({ choiceIndex: 0 });
// ink 执行：treasury -= 20, ming_years += 2
// 新状态：{ treasury: 80, ming_years: 2, situation: "reform" }

// 4. 检索记忆
const memories = await memorySystem.retrieve({
  sessionId,
  query: "整顿吏治",
  limit: 5
});
// 返回：[]（第一次玩，没有历史）

// 5. 调用大模型生成剧情
const systemPrompt = `
你是崇祯皇帝剧本的叙事者。

当前章节：第1章
当前局势：reform（改革）
状态变量：
- 库银：80（-20）
- 为大明续命：2年（+2）
- 军队士气：50
- 叛乱威胁：80

请根据玩家的选择"整顿吏治"，生成生动的剧情描述。
注意体现库银减少和改革带来的影响。
`;

const llmResponse = await callLLM(systemPrompt, userInput);
// 返回：
// "你召集内阁大臣，下令彻查各地贪官污吏。
//  户部尚书报告，此次整顿需耗费库银二十万两。
//  虽然国库吃紧，但你坚信整顿吏治是长久之计。
//  三个月后，数十名贪官被革职查办，朝野震动..."

// 6. 判定器评估
const judgment = await evaluator.judge({
  chapter: 1,
  situation: "reform",
  variables: { treasury: 80, ming_years: 2 },
  llmResponse
});
// 返回：
// {
//   situationScore: 30,  // 才刚开始改革
//   shouldAdvanceChapter: false,  // 还不够推进到下一章
//   shouldEndStory: false,
//   rationale: "改革刚刚开始，需要继续处理后续事件"
// }

// 7. 更新数据库
await db.insert("chat_messages", [
  { role: "user", content: "我要整顿吏治" },
  { role: "assistant", content: llmResponse }
]);

await db.update("session_state", {
  session_id: sessionId,
  state_variables: { treasury: 80, ming_years: 2 },
  current_situation: "reform"
});

await db.insert("situation_states", {
  session_id: sessionId,
  situation_id: "reform",
  completion_score: 30,
  rationale: "改革刚刚开始"
});

// 8. 返回给客户端
return {
  response: llmResponse,
  choices: ["继续推进改革", "暂缓改革，观察局势"],
  state: {
    chapter: 1,
    situation: "reform",
    variables: { treasury: 80, ming_years: 2 }
  }
};
```

## ink 与大模型的分工

| 组件 | 职责 | 示例 |
|------|------|------|
| **ink** | 定义结构、管理状态、条件判断 | `VAR treasury = 100`<br/>`~ treasury -= 20`<br/>`{ treasury < 0: -> game_over }` |
| **大模型** | 生成具体内容、描述剧情 | "你召集内阁大臣，下令彻查..."<br/>"三个月后，数十名贪官被革职..." |
| **判定器** | 评估进度、决定推进 | "改革完成度30%，不推进章节" |

## 数据库表结构

```sql
-- 会话表
CREATE TABLE chat_sessions (
  id UUID PRIMARY KEY,
  user_id UUID,
  story_id TEXT,
  current_chapter INT DEFAULT 1,
  current_situation TEXT DEFAULT 'initial',
  state_variables JSONB,  -- ink 变量状态
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- 对话消息
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES chat_sessions(id),
  role TEXT,  -- 'user' | 'assistant'
  content TEXT,
  created_at TIMESTAMP
);

-- 局势状态
CREATE TABLE situation_states (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES chat_sessions(id),
  situation_id TEXT,
  completion_score INT,  -- 0-100
  rationale TEXT,
  created_at TIMESTAMP
);

-- 记忆记录
CREATE TABLE memory_records (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES chat_sessions(id),
  chapter INT,
  summary TEXT,
  embedding VECTOR(1536),
  importance FLOAT,
  created_at TIMESTAMP
);
```

## Flutter 客户端调用

```dart
// 1. 发送用户输入
final response = await supabase.functions.invoke(
  'agent-orchestrator',
  body: {
    'sessionId': sessionId,
    'userId': userId,
    'storyId': 'chongzhen',
    'userInput': '我要整顿吏治',
  },
);

// 2. 处理响应
final result = response.data;
setState(() {
  messages.add(ChatMessage(
    role: MessageRole.assistant,
    content: result['response'],
  ));
  
  currentChapter = result['updatedState']['currentChapter'];
  currentSituation = result['updatedState']['currentSituation'];
  stateVariables = result['updatedState']['stateVariables'];
  
  // 显示是否推进章节的提示
  if (result['decision']['shouldAdvanceChapter']) {
    showDialog(context, '恭喜！进入第${currentChapter}章');
  }
});
```

## 总结

### Agent 架构的优势

✅ **状态管理**：ink 管理剧本状态和变量  
✅ **内容生成**：大模型生成生动的剧情  
✅ **智能判定**：判定器决定剧情推进  
✅ **数据持久化**：自动保存进度和状态  
✅ **可扩展性**：易于添加新章节、新局势  

### 关键点

1. **ink 不生成内容**，只定义结构和逻辑
2. **大模型不管理状态**，只生成文本
3. **Agent 是大脑**，协调所有组件
4. **判定器是关键**，决定剧情何时推进

这样的架构才能实现真正的互动剧本游戏！
