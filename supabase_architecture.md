# AI剧本互动应用技术架构（Supabase 方案）

## 1. 项目目标
- **核心体验**：在 Flutter 客户端中，基于大模型与 `ink` 剧本实现章节-局势-结局的互动体验。
- **关键需求**：连续对话、局势判定、记忆管理、用户进度保存、低运营成本的云端部署。

## 2. 总体架构概览
```mermaid
flowchart LR
    subgraph Client[Flutter 客户端]
        UI[对话/局势 UI]
        State[Riverpod/BLoC 状态]
    end

    subgraph Supabase[Supabase 平台]
        Auth[Auth & Row Level Security]
        EdgeFuncs[Edge Functions]
        DB[(Postgres + Row Level Policies)]
        Storage[(Storage Bucket)]
        Realtime[(Realtime Channels)]
    end

    subgraph Services[扩展服务]
        InkRuntime[inkjs Runtime (Edge Function)]
        MemorySvc[记忆服务]
        VectorDB[(Supabase Vector or 外部向量库)]
        LLMProxy[Replicate API Proxy]
    end

    Client -->|HTTPS/WebSocket| Auth
    Client -->|会话API| EdgeFuncs
    EdgeFuncs --> DB
    EdgeFuncs --> Storage
    EdgeFuncs --> Realtime
    EdgeFuncs --> InkRuntime
    InkRuntime --> MemorySvc
    MemorySvc --> VectorDB
    MemorySvc --> LLMProxy
    LLMProxy -->|REST| Replicate[(Replicate LLM)]
    MemorySvc --> DB
    EdgeFuncs --> Client
```

## 3. 关键组件与职责
- **Flutter 客户端**
  - UI：对话流、局势卡片、章节地图。
  - 状态：`riverpod`/`flutter_bloc` 管理局势与对话上下文，使用 `isar`/`hive` 做本地缓存。
  - 通信：通过 Supabase SDK 调用 Edge Function，订阅 Realtime 更新。

- **Supabase Auth**
  - 支持邮箱/第三方登录，利用 Row Level Security 保护用户数据。
  - 通过 JWT 将用户身份透传给 Edge Functions。

- **Supabase Postgres**
  - 表结构建议：`users`、`stories`、`chapters`、`situations`、`session_logs`、`memory_records`。
  - 使用行级策略区分不同用户或剧本作者权限。

- **Supabase Storage**
  - 存放剧本插画、语音、封面等静态资源。

- **Supabase Realtime**
  - 推送局势状态或多人协作会话的更新。

- **Edge Functions（Deno）**
  - `orchestrator`：接收客户端请求，协调 ink、记忆与大模型。
  - `ink-runtime`：封装 `inkjs`，解析 `.ink` 剧本并返回下一节点。
  - `memory-service`：管理短期上下文（Redis/缓存）与长期向量检索。
  - `llm-proxy`：统一访问 Replicate API，处理重试、速率限制、日志。
  - 可使用 `Supabase Functions` 超时与并发限制，必要时拆分成多个函数。

- **记忆系统**
  - **短期**：保存在 Supabase KV/Edge Function 内存或 Redis（可通过外部 Upstash Redis）。
  - **长期**：使用 Supabase Vector 扩展（或外部 Pinecone/Milvus），存储摘要、角色设定。
  - **摘要**：调用轻量模型（Replicate MiniLM/BGE）生成记忆记录。

- **Replicate 模型**
  - 建议模型：`openai/gpt-5-mini`（原生支持 `messages` 历史），可选备用：`meta/meta-llama-3-70b-instruct`、`mistralai/mixtral-8x7b-instruct` 等。
  - 输出格式通过 `json_schema`/手动模板控制，返回局势判定与下一步剧情建议。

## 4. 核心数据流
1. **用户对话**：
   - Flutter -> Edge Function(`orchestrator`)：携带用户消息与会话 ID。
   - Edge Function：调用 `ink-runtime` 获取当前局势描述；向 `memory-service` 拉取短期上下文、检索长期记忆。
   - `llm-proxy` 调用 Replicate，获得 AI 响应与局势判定。
   - 结果写入 `session_logs`、`situations` 状态；通过 Realtime 推送给客户端。

2. **局势判定**：
   - 模型输出 `{situation_id, completion_score, rationale}`。
   - Edge Function 根据分数触发状态机更新（写库），如完成则推进 `chapters`。

3. **记忆更新**：
   - 判断触发条件（如章节结束）后生成摘要，存入 `memory_records` + 向量库。
   - 维护短期对话窗口（截断最近 N 轮）写入缓存。

## 5. 技术可行性评估
- **Supabase 优势**：一体化提供 Auth、Postgres、存储、实时能力，适合快速迭代；Edge Functions 支持直接访问数据库并执行 Deno 代码。
- **`inkjs` 部署**：通过 Edge Function 引入 `inkjs` npm 包可运行剧本逻辑；需注意冷启动时的初始化开销。
- **Replicate 集成**：Edge Function 调用外部 REST API 可行，需将 Replicate token 存储在 Supabase Secrets。
- **记忆系统**：Supabase Vector 简化向量检索部署；若需更大规模，可切换到外部向量服务。
- **性能**：Edge Function 默认约 10 秒超时，可通过任务拆分或在函数内发起后台队列（Supabase 未来事件/第三方队列）。

## 6. 风险与应对
- **模型调用延迟**：通过并行获取记忆、提前加载 prompt，或使用缓存回答降低延迟。
- **Edge Function 冷启动**：维持最小依赖体积，利用预热任务或改用持久化服务（如 Fly.io）承载重计算。
- **成本控制**：设置调用配额、缓存常见响应；必要时混用自托管模型。
- **安全与合规**：结合 Supabase 行级策略、防止跨用户数据访问；增加输出审核流程。

## 7. MVP 迭代建议
- **迭代1**：基础登录、单章节 `.ink` 剧本、短期记忆窗口、Replicate 单模型。
- **迭代2**：加入长期记忆摘要、局势判定 JSON 结构化输出、Supabase Realtime 推送。
- **迭代3**：开放剧本管理工具、多人协作、成本优化（模型混用/缓存）。
