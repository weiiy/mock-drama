# Agent 框架选择指南

## 一、框架推荐（按优先级）

### 🥇 第一梯队：专业 Agent 框架

#### 1. **LangGraph** (LangChain) ⭐⭐⭐⭐⭐
- **定位**：构建有状态的多 Agent 应用
- **优势**：
  - 🔄 **状态管理**：内置状态机，完美适合剧情推进
  - 📊 **可视化**：流程图可视化，易于调试
  - 🔧 **灵活性**：可以定义复杂的工作流
  - 🧩 **组件丰富**：与 LangChain 生态集成
  - 📚 **文档完善**：大量示例和教程
- **劣势**：
  - 📈 学习曲线稍陡
  - 🐍 仅支持 Python
- **适用场景**：复杂剧情、多步骤推理、需要状态管理

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict, Annotated
import operator

# 定义状态
class StoryState(TypedDict):
    chapter: int
    situation: str
    variables: dict
    messages: Annotated[list, operator.add]
    decision: dict

# 创建图
workflow = StateGraph(StoryState)

# 定义节点
def get_ink_state(state):
    """获取 ink 状态"""
    ink_state = call_ink_engine(state)
    return {"ink_state": ink_state}

def retrieve_memories(state):
    """检索记忆"""
    memories = search_vector_db(state["messages"][-1])
    return {"memories": memories}

def generate_story(state):
    """生成剧情"""
    response = call_llm(state)
    return {"messages": [response]}

def judge_situation(state):
    """判定推进"""
    decision = evaluate_progress(state)
    return {"decision": decision}

def update_state(state):
    """更新状态"""
    if state["decision"]["shouldAdvanceChapter"]:
        return {"chapter": state["chapter"] + 1}
    return {}

# 添加节点
workflow.add_node("ink", get_ink_state)
workflow.add_node("memory", retrieve_memories)
workflow.add_node("generate", generate_story)
workflow.add_node("judge", judge_situation)
workflow.add_node("update", update_state)

# 定义边
workflow.set_entry_point("ink")
workflow.add_edge("ink", "memory")
workflow.add_edge("memory", "generate")
workflow.add_edge("generate", "judge")

# 条件分支
def should_continue(state):
    if state["decision"]["shouldEndStory"]:
        return "end"
    return "update"

workflow.add_conditional_edges(
    "judge",
    should_continue,
    {
        "update": "update",
        "end": END
    }
)
workflow.add_edge("update", END)

# 编译并运行
app = workflow.compile()
result = app.invoke({
    "chapter": 1,
    "situation": "initial",
    "variables": {},
    "messages": [{"role": "user", "content": "我要整顿吏治"}]
})
```

**为什么推荐**：
- ✅ 完美适合故事推进的状态机模型
- ✅ 可以清晰定义：ink → 记忆 → LLM → 判定 → 更新
- ✅ 支持循环和条件分支
- ✅ 内置检查点，可以暂停和恢复

#### 2. **CrewAI** ⭐⭐⭐⭐
- **定位**：多 Agent 协作框架
- **优势**：
  - 👥 **多 Agent**：可以定义多个角色（叙事者、判定者、记忆管理者）
  - 🎭 **角色扮演**：每个 Agent 有自己的角色和目标
  - 🔧 **简单易用**：配置式开发，代码量少
  - 🚀 **快速上手**：学习曲线平缓
- **劣势**：
  - 🔒 灵活性不如 LangGraph
  - 📊 状态管理较弱
- **适用场景**：多角色协作、简单工作流

```python
from crewai import Agent, Task, Crew

# 定义 Agent
narrator = Agent(
    role='故事叙事者',
    goal='根据玩家选择生成生动的剧情',
    backstory='你是一位经验丰富的历史小说家',
    llm='claude-3-5-sonnet'
)

judge = Agent(
    role='剧情判定者',
    goal='评估剧情进展，决定是否推进章节',
    backstory='你是一位严谨的游戏设计师',
    llm='gpt-4o-mini'
)

memory_keeper = Agent(
    role='记忆管理者',
    goal='检索和管理历史事件',
    backstory='你负责维护故事的连贯性',
    llm='gpt-4o-mini'
)

# 定义任务
narrate_task = Task(
    description='根据玩家输入"{user_input}"生成剧情',
    agent=narrator
)

judge_task = Task(
    description='评估剧情进展，判断是否推进',
    agent=judge,
    context=[narrate_task]  # 依赖叙事任务
)

# 创建 Crew
crew = Crew(
    agents=[narrator, judge, memory_keeper],
    tasks=[narrate_task, judge_task],
    verbose=True
)

# 执行
result = crew.kickoff(inputs={"user_input": "我要整顿吏治"})
```

**为什么推荐**：
- ✅ 适合将 Agent 分解为多个角色
- ✅ 代码简洁，易于维护
- ✅ 自动处理 Agent 间通信

#### 3. **AutoGen** (Microsoft) ⭐⭐⭐⭐
- **定位**：多 Agent 对话框架
- **优势**：
  - 💬 **对话式**：Agent 之间可以对话
  - 🔧 **工具调用**：支持 Function Calling
  - 🏢 **企业级**：Microsoft 支持
  - 📚 **文档完善**
- **劣势**：
  - 🎯 更适合对话场景，不太适合状态机
  - 🐌 性能一般
- **适用场景**：多 Agent 讨论、复杂决策

```python
from autogen import AssistantAgent, UserProxyAgent

# 定义 Agent
narrator = AssistantAgent(
    name="narrator",
    system_message="你是故事叙事者",
    llm_config={"model": "claude-3-5-sonnet"}
)

judge = AssistantAgent(
    name="judge",
    system_message="你是剧情判定者",
    llm_config={"model": "gpt-4o-mini"}
)

# Agent 对话
narrator.initiate_chat(
    judge,
    message="玩家选择了整顿吏治，我生成了以下剧情：..."
)
```

### 🥈 第二梯队：轻量级框架

#### 4. **LangChain** (不使用 LangGraph) ⭐⭐⭐
- **定位**：LLM 应用开发框架
- **优势**：
  - 🧩 **组件丰富**：Chains, Memory, Tools
  - 🌐 **生态完善**：大量集成
  - 📚 **社区活跃**
- **劣势**：
  - 🔄 状态管理较弱（需要 LangGraph）
  - 📈 复杂度高
- **适用场景**：简单 Agent、快速原型

```python
from langchain.chains import LLMChain
from langchain.memory import ConversationBufferMemory
from langchain_anthropic import ChatAnthropic

llm = ChatAnthropic(model="claude-3-5-sonnet")
memory = ConversationBufferMemory()

chain = LLMChain(
    llm=llm,
    memory=memory,
    prompt=story_prompt
)

response = chain.run(user_input="我要整顿吏治")
```

#### 5. **Semantic Kernel** (Microsoft) ⭐⭐⭐
- **定位**：跨语言 AI 编排框架
- **优势**：
  - 🌐 **多语言**：Python, C#, Java
  - 🔧 **插件系统**：易于扩展
  - 🏢 **企业级**
- **劣势**：
  - 📚 文档较少
  - 🐛 相对不成熟
- **适用场景**：需要多语言支持

#### 6. **Haystack** ⭐⭐⭐
- **定位**：NLP 和 RAG 框架
- **优势**：
  - 🔍 **RAG 优秀**：检索增强生成
  - 📊 **Pipeline**：清晰的管道结构
- **劣势**：
  - 🎯 更适合 RAG，不太适合 Agent
- **适用场景**：需要大量检索的场景

### 🥉 第三梯队：自建方案

#### 7. **纯 FastAPI + Celery** ⭐⭐⭐⭐
- **定位**：完全自定义
- **优势**：
  - 🔧 **完全控制**：没有框架限制
  - ⚡ **性能最优**：没有额外开销
  - 📦 **轻量级**：只用需要的组件
- **劣势**：
  - 🛠️ 需要自己实现所有逻辑
  - 📈 开发时间长
- **适用场景**：有明确需求、追求极致性能

```python
# 就是我们之前创建的 agent-server/main.py
# 完全自定义，灵活性最高
```

## 二、针对故事推进场景的推荐

### 🎯 最佳选择：LangGraph

**理由**：
1. ✅ **状态机模型**：完美匹配剧情推进逻辑
2. ✅ **可视化流程**：易于理解和调试
3. ✅ **检查点系统**：可以保存和恢复游戏进度
4. ✅ **条件分支**：支持复杂的剧情分支
5. ✅ **循环支持**：可以在章节内循环

### 完整示例：使用 LangGraph 构建故事 Agent

```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.sqlite import SqliteSaver
from typing import TypedDict, Annotated, Literal
import operator

# ============ 1. 定义状态 ============
class StoryState(TypedDict):
    # 基础信息
    session_id: str
    story_id: str
    user_input: str
    
    # 剧情状态
    chapter: int
    situation: str
    state_variables: dict
    
    # 对话历史
    messages: Annotated[list, operator.add]
    
    # 中间结果
    ink_state: dict
    memories: list
    llm_response: str
    decision: dict
    
    # 控制流
    next_action: Literal["continue", "advance_chapter", "end_story"]

# ============ 2. 定义节点函数 ============

def load_session(state: StoryState) -> dict:
    """加载会话状态"""
    from database import get_session
    session = get_session(state["session_id"])
    return {
        "chapter": session["chapter"],
        "situation": session["situation"],
        "state_variables": session["state_variables"],
        "messages": session["messages"][-10:]  # 最近10条
    }

def get_ink_state(state: StoryState) -> dict:
    """调用 ink 引擎"""
    from ink_engine import InkEngine
    engine = InkEngine(state["story_id"])
    ink_state = engine.get_state(
        chapter=state["chapter"],
        variables=state["state_variables"]
    )
    return {"ink_state": ink_state}

def retrieve_memories(state: StoryState) -> dict:
    """检索相关记忆"""
    from vector_db import search_memories
    memories = search_memories(
        session_id=state["session_id"],
        query=state["user_input"],
        limit=5
    )
    return {"memories": memories}

def generate_story(state: StoryState) -> dict:
    """调用 LLM 生成剧情"""
    from anthropic import Anthropic
    
    client = Anthropic()
    
    # 构建提示词
    system_prompt = f"""
你是{state['story_id']}剧本的叙事者。

当前章节：第{state['chapter']}章
当前局势：{state['situation']}
状态变量：{state['state_variables']}

历史记忆：
{chr(10).join([m['summary'] for m in state['memories']])}

请根据玩家的选择生成生动的剧情。
"""
    
    response = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=1024,
        messages=[
            {"role": "system", "content": system_prompt},
            *state["messages"],
            {"role": "user", "content": state["user_input"]}
        ]
    )
    
    llm_response = response.content[0].text
    
    return {
        "llm_response": llm_response,
        "messages": [{"role": "assistant", "content": llm_response}]
    }

def judge_situation(state: StoryState) -> dict:
    """判定剧情进展"""
    from openai import OpenAI
    
    client = OpenAI()
    
    judgment_prompt = f"""
判断剧情进展：

当前章节：{state['chapter']}
状态变量：{state['state_variables']}
最新剧情：{state['llm_response']}

返回 JSON：
{{
  "situationScore": 0-100,
  "shouldAdvanceChapter": true/false,
  "shouldEndStory": true/false,
  "rationale": "理由",
  "stateChanges": {{"variable": value}}
}}
"""
    
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": judgment_prompt}],
        response_format={"type": "json_object"}
    )
    
    decision = json.loads(response.choices[0].message.content)
    
    # 决定下一步
    if decision["shouldEndStory"]:
        next_action = "end_story"
    elif decision["shouldAdvanceChapter"]:
        next_action = "advance_chapter"
    else:
        next_action = "continue"
    
    return {
        "decision": decision,
        "next_action": next_action
    }

def update_database(state: StoryState) -> dict:
    """更新数据库"""
    from database import save_message, update_session
    
    # 保存消息
    save_message(
        session_id=state["session_id"],
        role="user",
        content=state["user_input"]
    )
    save_message(
        session_id=state["session_id"],
        role="assistant",
        content=state["llm_response"]
    )
    
    # 更新会话状态
    new_variables = {
        **state["state_variables"],
        **state["decision"].get("stateChanges", {})
    }
    
    new_chapter = state["chapter"]
    if state["next_action"] == "advance_chapter":
        new_chapter += 1
    
    update_session(
        session_id=state["session_id"],
        chapter=new_chapter,
        situation=state["situation"],
        state_variables=new_variables
    )
    
    return {
        "chapter": new_chapter,
        "state_variables": new_variables
    }

def end_story(state: StoryState) -> dict:
    """结束故事"""
    from database import mark_story_completed
    mark_story_completed(state["session_id"])
    return {"next_action": "end_story"}

# ============ 3. 构建图 ============

def create_story_graph():
    workflow = StateGraph(StoryState)
    
    # 添加节点
    workflow.add_node("load", load_session)
    workflow.add_node("ink", get_ink_state)
    workflow.add_node("memory", retrieve_memories)
    workflow.add_node("generate", generate_story)
    workflow.add_node("judge", judge_situation)
    workflow.add_node("update", update_database)
    workflow.add_node("end", end_story)
    
    # 定义流程
    workflow.set_entry_point("load")
    workflow.add_edge("load", "ink")
    workflow.add_edge("ink", "memory")
    workflow.add_edge("memory", "generate")
    workflow.add_edge("generate", "judge")
    
    # 条件分支
    def route_after_judge(state: StoryState) -> str:
        if state["next_action"] == "end_story":
            return "end"
        else:
            return "update"
    
    workflow.add_conditional_edges(
        "judge",
        route_after_judge,
        {
            "update": "update",
            "end": "end"
        }
    )
    
    workflow.add_edge("update", END)
    workflow.add_edge("end", END)
    
    # 添加检查点（可以保存和恢复）
    memory = SqliteSaver.from_conn_string(":memory:")
    
    return workflow.compile(checkpointer=memory)

# ============ 4. 使用 ============

# 创建图
app = create_story_graph()

# 运行
config = {"configurable": {"thread_id": "session_123"}}
result = app.invoke(
    {
        "session_id": "session_123",
        "story_id": "chongzhen",
        "user_input": "我要整顿吏治"
    },
    config=config
)

# 可以暂停和恢复
# 下次继续游戏时，使用相同的 thread_id 即可恢复状态
```

## 三、框架对比表

| 框架 | 学习曲线 | 灵活性 | 状态管理 | 多Agent | 性能 | 推荐度 |
|------|---------|--------|---------|---------|------|--------|
| **LangGraph** | 中 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **CrewAI** | 低 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **AutoGen** | 中 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **LangChain** | 高 | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **纯 FastAPI** | 低 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## 四、最终推荐

### 🎯 最佳方案：LangGraph + FastAPI + Celery

```
FastAPI (Web 服务器)
    ↓
Celery (任务队列)
    ↓
LangGraph (Agent 编排)
    ├── ink 引擎
    ├── 记忆系统
    ├── LLM (Claude/GPT)
    └── 判定器
```

**理由**：
- ✅ FastAPI：高性能 Web 服务
- ✅ Celery：处理长时间任务
- ✅ LangGraph：清晰的 Agent 流程
- ✅ 最佳实践组合

### 代码结构

```
agent-server/
├── main.py              # FastAPI 服务器
├── celery_app.py        # Celery 配置
├── agent/
│   ├── graph.py         # LangGraph 定义
│   ├── nodes.py         # 节点函数
│   └── state.py         # 状态定义
├── services/
│   ├── ink_engine.py    # ink 引擎
│   ├── memory.py        # 记忆系统
│   └── llm.py           # LLM 客户端
└── database/
    └── models.py        # 数据库模型
```

## 五、快速开始

```bash
# 安装依赖
pip install langgraph langchain-anthropic langchain-openai fastapi celery redis

# 创建 Agent
python create_agent.py

# 启动服务
uvicorn main:app --reload

# 启动 Worker
celery -A celery_app worker --loglevel=info
```

这样的架构既有框架的便利性，又保持了灵活性和性能！
