# Replicate API 集成

## ✅ 已完成的修改

### 1. 创建 Replicate LLM 包装器

**文件**: `agent-server/replicate_llm.py`

- 实现了 LangChain 兼容的 Replicate LLM 类
- 支持 `openai/gpt-5-mini` 模型
- 自动轮询预测结果
- 错误处理和超时机制

### 2. 修改 CrewAI Agent

**文件**: `agent-server/crewai_story_agent.py`

- 导入 `create_replicate_llm`
- 在 `__init__` 中初始化 Replicate LLM
- 为所有 Agent 添加 `llm=self.llm` 参数：
  - narrator (叙事者)
  - situation_judge (局势判定者)
  - character_manager (角色管理者)
  - chapter_coordinator (章节协调者)
  - ending_generator (结局生成器)

### 3. 更新依赖

**文件**: `agent-server/requirements.txt`

添加了：
```
langchain>=0.1.20
langchain-core>=0.1.0
langchain-community>=0.0.38
```

## 🔧 配置

### 环境变量

确保 `agent-server/.env` 中配置了：

```env
REPLICATE_API_TOKEN=r8_your_token_here
```

### 获取 Replicate API Token

1. 访问 https://replicate.com/
2. 注册/登录账号
3. 进入 Account Settings → API Tokens
4. 复制 API Token
5. 粘贴到 `.env` 文件

## 📊 API 调用流程

```
Flutter App
    ↓
    POST /api/story/action
    {session_id, user_input}
    ↓
Agent Server (FastAPI)
    ↓
CrewAI Agents
    ↓
Replicate LLM (ReplicateLLM class)
    ↓
    1. POST https://api.replicate.com/v1/models/openai/gpt-5-mini/predictions
    2. 获取 prediction_id 和 get_url
    3. 轮询 GET get_url 直到状态为 "succeeded"
    4. 返回生成的文本
    ↓
解析结果并更新数据库
    ↓
返回给 Flutter App
```

## 🎯 使用的模型

**模型**: `openai/gpt-5-mini`
- 快速响应
- 成本较低
- 适合对话生成

**参数**:
- `max_tokens`: 1024
- `temperature`: 0.7
- `reasoning_effort`: medium

## 🔄 与 Supabase Edge Function 的对比

### Supabase Edge Function (之前)
```typescript
// 直接调用 Replicate API
const streamUrl = await createReplicatePrediction({
  messages: formattedMessages,
  maxOutputTokens: 1024,
}, replicateToken);

// 流式输出
for await (const chunk of streamReplicateOutput(streamUrl, replicateToken)) {
  // 发送 SSE
}
```

### Agent Server (现在)
```python
# 通过 LangChain 包装器调用
llm = create_replicate_llm(
    model="openai/gpt-5-mini",
    max_tokens=1024,
    temperature=0.7
)

# CrewAI Agent 使用
agent = Agent(
    role='故事叙事者',
    goal='生成剧情',
    llm=llm  # 使用 Replicate
)
```

## ✅ 优势

1. **统一接口**: 所有 Agent 使用相同的 LLM
2. **易于切换**: 可以轻松切换到其他 LLM (OpenAI, Anthropic)
3. **错误处理**: 统一的错误处理和重试机制
4. **成本控制**: 可以监控和限制 API 调用

## 🐛 故障排查

### 问题 1: ModuleNotFoundError: No module named 'langchain'

**解决**: 重新构建 Docker 镜像
```bash
docker compose up -d --build
```

### 问题 2: Replicate API 地区限制

**错误**: `Country, region, or territory not supported`

**解决**:
1. 使用 VPN 连接到支持的地区
2. 或切换到其他 LLM:
   ```python
   from langchain.chat_models import ChatOpenAI
   llm = ChatOpenAI(model="gpt-4", temperature=0.7)
   ```

### 问题 3: API Token 无效

**错误**: `Error code: 401 - Unauthorized`

**解决**:
1. 检查 `.env` 中的 `REPLICATE_API_TOKEN`
2. 确认 Token 有效且未过期
3. 重启服务: `docker compose restart web`

## 🧪 测试

### 1. 测试健康检查

```bash
curl http://localhost:8000/health
```

### 2. 创建会话

```bash
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user",
    "story_id": "chongzhen"
  }'
```

### 3. 测试剧情生成

```bash
curl -X POST http://localhost:8000/api/story/action \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "your-session-id",
    "user_input": "我要铲除魏忠贤"
  }'
```

应该返回：
```json
{
  "story": "剧情描述...",
  "situation_update": {...},
  "character_updates": [...],
  "chapter_status": "continue"
}
```

## 📝 下一步优化

1. **添加缓存**: 缓存常见的剧情片段
2. **批量处理**: 合并多个 Agent 调用
3. **流式输出**: 支持 SSE 流式返回
4. **监控**: 添加 API 调用监控和日志
5. **降级策略**: API 失败时使用预设剧情

## 🎉 完成

Replicate API 已成功集成到 CrewAI Agent 中！现在可以使用 `openai/gpt-5-mini` 模型生成剧情了。
