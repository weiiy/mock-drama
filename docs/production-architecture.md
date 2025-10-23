# 生产级 Agent 架构方案

## AI Dungeon 的架构推测

AI Dungeon 作为成熟的 AI 互动游戏，可能采用以下架构：

```
┌─────────────┐
│   客户端     │ (Web/Mobile)
└──────┬──────┘
       │ HTTPS/WebSocket
       ▼
┌─────────────────────────────────────┐
│        API Gateway / Load Balancer   │
│         (Nginx / AWS ALB)            │
└──────────────┬──────────────────────┘
               │
       ┌───────┴───────┐
       ▼               ▼
┌─────────────┐  ┌─────────────┐
│  Web Server │  │  Web Server │  (多实例)
│  (FastAPI)  │  │  (FastAPI)  │
└──────┬──────┘  └──────┬──────┘
       │                │
       └────────┬───────┘
                ▼
    ┌──────────────────────┐
    │   Message Queue      │
    │   (Redis / RabbitMQ) │
    └──────────┬───────────┘
               │
       ┌───────┴───────┐
       ▼               ▼
┌─────────────┐  ┌─────────────┐
│Agent Worker │  │Agent Worker │  (多进程/多容器)
│  (Python)   │  │  (Python)   │
└──────┬──────┘  └──────┬──────┘
       │                │
       └────────┬───────┘
                ▼
    ┌──────────────────────┐
    │    Database          │
    │  (PostgreSQL)        │
    └──────────────────────┘
                │
    ┌──────────────────────┐
    │   Vector Database    │
    │  (Pinecone/Weaviate) │
    └──────────────────────┘
                │
    ┌──────────────────────┐
    │   LLM API            │
    │  (OpenAI/Anthropic)  │
    └──────────────────────┘
```

## 推荐方案：混合架构

### 方案 A：Supabase + 独立 Agent 服务器（推荐）

```
┌─────────────┐
│   Flutter   │
└──────┬──────┘
       │
   ┌───┴────┐
   ▼        ▼
┌──────┐  ┌──────────────────┐
│Supabase│  │ Agent Server     │
│        │  │ (Fly.io/Railway) │
│- Auth  │  │                  │
│- DB    │  │ - FastAPI/Hono   │
│- Storage│ │ - Redis          │
└────────┘  │ - Agent Workers  │
            └──────────────────┘
```

**优势**：
- ✅ Supabase 处理认证、数据库、存储
- ✅ 独立服务器运行复杂 Agent 逻辑
- ✅ 可以使用任何语言（Python/Node.js/Go）
- ✅ 无超时限制
- ✅ 易于扩展和监控

### 方案 B：完全自建（大规模）

```
Kubernetes 集群
├── API Gateway (Nginx Ingress)
├── Web Server Pods (FastAPI)
├── Agent Worker Pods (Celery)
├── Redis Cluster
├── PostgreSQL (Managed)
└── Vector DB (Pinecone)
```

**适用场景**：用户量 > 10万

## 具体实现：方案 A 详解

### 1. 技术栈选择

#### 后端语言对比

| 语言 | 优势 | 劣势 | 推荐度 |
|------|------|------|--------|
| **Python** | 🟢 AI 生态最好<br/>🟢 库丰富（LangChain等）<br/>🟢 易于开发 | 🔴 性能较低<br/>🔴 并发处理弱 | ⭐⭐⭐⭐⭐ |
| **Node.js** | 🟢 高并发<br/>🟢 与 Supabase 集成好<br/>🟢 TypeScript 类型安全 | 🔴 AI 库较少<br/>🔴 异步复杂 | ⭐⭐⭐⭐ |
| **Go** | 🟢 高性能<br/>🟢 并发优秀<br/>🟢 部署简单 | 🔴 AI 库少<br/>🔴 开发效率低 | ⭐⭐⭐ |

**推荐：Python (FastAPI) + Redis + Celery**

### 2. 架构设计

```python
# main.py - FastAPI 服务器
from fastapi import FastAPI, WebSocket
from celery import Celery
import redis

app = FastAPI()
celery_app = Celery('agent', broker='redis://localhost:6379')
redis_client = redis.Redis(host='localhost', port=6379)

@app.post("/api/story/action")
async def process_action(request: ActionRequest):
    """
    接收用户输入，提交到 Celery 队列
    """
    task = process_story_action.delay(
        session_id=request.session_id,
        user_input=request.user_input
    )
    
    return {"task_id": task.id, "status": "processing"}

@app.get("/api/story/status/{task_id}")
async def get_status(task_id: str):
    """
    查询任务状态
    """
    task = celery_app.AsyncResult(task_id)
    return {
        "status": task.state,
        "result": task.result if task.ready() else None
    }

@app.websocket("/ws/story/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    """
    WebSocket 实时推送
    """
    await websocket.accept()
    
    # 订阅 Redis 频道
    pubsub = redis_client.pubsub()
    pubsub.subscribe(f"session:{session_id}")
    
    for message in pubsub.listen():
        if message['type'] == 'message':
            await websocket.send_json(json.loads(message['data']))

# agent_worker.py - Celery Worker
from celery import Celery
from agent import StoryAgent

celery_app = Celery('agent', broker='redis://localhost:6379')

@celery_app.task(bind=True, max_retries=3)
def process_story_action(self, session_id: str, user_input: str):
    """
    在 Worker 中运行 Agent
    """
    try:
        # 1. 加载会话状态
        state = load_session_state(session_id)
        
        # 2. 创建 Agent
        agent = StoryAgent(session_id)
        
        # 3. 处理输入（可能需要 30-60 秒）
        result = agent.process_input(state, user_input)
        
        # 4. 保存状态到数据库
        save_session_state(session_id, result['updated_state'])
        
        # 5. 通过 Redis 推送结果
        redis_client.publish(
            f"session:{session_id}",
            json.dumps(result)
        )
        
        return result
        
    except Exception as e:
        # 重试机制
        self.retry(exc=e, countdown=5)

# agent.py - Agent 实现
class StoryAgent:
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.ink_engine = InkEngine()
        self.memory_system = MemorySystem()
        self.llm_client = LLMClient()
        
    async def process_input(self, state: AgentState, user_input: str):
        """
        Agent 主流程
        """
        # 1. ink 引擎
        ink_state = await self.ink_engine.get_state(state)
        
        # 2. 记忆检索
        memories = await self.memory_system.retrieve(
            session_id=self.session_id,
            query=user_input,
            limit=5
        )
        
        # 3. 调用 LLM（可能需要 10-20 秒）
        llm_response = await self.llm_client.generate(
            state=state,
            ink_state=ink_state,
            memories=memories,
            user_input=user_input
        )
        
        # 4. 判定器（再次调用 LLM，5-10 秒）
        decision = await self.evaluate_situation(
            state=state,
            llm_response=llm_response
        )
        
        # 5. 更新状态
        updated_state = self.update_state(state, decision)
        
        return {
            "response": llm_response,
            "decision": decision,
            "updated_state": updated_state
        }
```

### 3. 部署方案

#### 选项 1：Fly.io（推荐）

```toml
# fly.toml
app = "mock-drama-agent"

[build]
  builder = "paketobuildpacks/builder:base"

[[services]]
  internal_port = 8000
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]
  
  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

[env]
  PORT = "8000"
  REDIS_URL = "redis://mock-drama-redis.internal:6379"

[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_gb = 2
```

**部署命令**：
```bash
# 部署 Web 服务器
fly deploy

# 部署 Redis
fly redis create

# 部署 Worker
fly scale count worker=3
```

**成本**：约 $15-30/月

#### 选项 2：Railway

```yaml
# railway.toml
[build]
  builder = "NIXPACKS"

[deploy]
  startCommand = "uvicorn main:app --host 0.0.0.0 --port $PORT"
  
[services.web]
  replicas = 2
  
[services.worker]
  replicas = 3
  startCommand = "celery -A agent_worker worker --loglevel=info"
```

**成本**：约 $20-40/月

#### 选项 3：自建 VPS（最便宜）

```bash
# 使用 Docker Compose
docker-compose up -d
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      - redis
    deploy:
      replicas: 2
  
  worker:
    build: .
    command: celery -A agent_worker worker --loglevel=info --concurrency=4
    environment:
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      - redis
    deploy:
      replicas: 3
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
  
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - web

volumes:
  redis_data:
```

**成本**：$5-10/月（Hetzner/DigitalOcean）

### 4. 并发处理策略

```python
# 使用 Celery 处理并发
from celery import group, chain, chord

# 并行执行多个任务
job = group(
    process_ink_state.s(session_id),
    retrieve_memories.s(session_id, user_input),
    load_conversation_history.s(session_id)
)

# 链式执行
result = chain(
    job,
    generate_llm_response.s(),
    evaluate_situation.s(),
    update_database.s()
).apply_async()
```

### 5. 性能优化

```python
# 1. 缓存 ink 剧本
from functools import lru_cache

@lru_cache(maxsize=100)
def load_ink_story(story_id: str):
    return InkStory.load(story_id)

# 2. 批量处理
async def batch_process_actions(actions: List[Action]):
    # 批量调用 LLM
    responses = await llm_client.batch_generate(actions)
    return responses

# 3. 连接池
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=40
)

# 4. 异步 I/O
import asyncio
import aiohttp

async def parallel_fetch():
    async with aiohttp.ClientSession() as session:
        tasks = [
            fetch_ink_state(session),
            fetch_memories(session),
            fetch_history(session)
        ]
        results = await asyncio.gather(*tasks)
    return results
```

## 完整架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                           │
└────────────────────────┬────────────────────────────────────┘
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
    ┌──────────────┐          ┌──────────────┐
    │  Supabase    │          │ Agent Server │
    │              │          │  (Fly.io)    │
    │ - Auth       │          │              │
    │ - Database   │◄─────────┤ - FastAPI    │
    │ - Storage    │          │ - Redis      │
    │ - Realtime   │          │ - Celery     │
    └──────────────┘          └──────┬───────┘
                                     │
                         ┌───────────┴───────────┐
                         ▼                       ▼
                  ┌─────────────┐        ┌─────────────┐
                  │ Worker 1    │        │ Worker 2    │
                  │             │        │             │
                  │ - Agent     │        │ - Agent     │
                  │ - ink       │        │ - ink       │
                  │ - LLM       │        │ - LLM       │
                  └─────────────┘        └─────────────┘
```

## 成本估算

### 小规模（< 1000 用户）
- Supabase Free: $0
- Fly.io (2 CPU, 2GB RAM): $15/月
- Redis: $5/月
- **总计：约 $20/月**

### 中等规模（1000-10000 用户）
- Supabase Pro: $25/月
- Fly.io (4 CPU, 4GB RAM): $40/月
- Redis: $10/月
- **总计：约 $75/月**

### 大规模（> 10000 用户）
- Supabase Pro: $25/月
- Kubernetes 集群: $200-500/月
- Redis Cluster: $50/月
- **总计：约 $300-600/月**

## 总结

### 推荐方案

**MVP 阶段**：
- Supabase（认证、数据库、存储）
- Fly.io（Agent 服务器）
- Python + FastAPI + Celery
- Redis（消息队列）

**扩展阶段**：
- 增加 Worker 数量
- 使用 Kubernetes
- 添加缓存层
- 优化 LLM 调用

这样的架构可以：
- ✅ 处理复杂 Agent 逻辑
- ✅ 支持高并发
- ✅ 无超时限制
- ✅ 易于扩展
- ✅ 成本可控
