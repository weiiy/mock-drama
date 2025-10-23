# 独立开发者成本分析

## 一、完整成本拆解

### 1. LLM API 成本

#### 方案 A：纯 Replicate（最便宜）

**模型选择**：
- 生成剧情：Llama 3.1 70B ($0.65 input, $2.75 output)
- 判定逻辑：Mistral 7B ($0.05 input, $0.25 output)

**假设**（每次对话）：
- 生成剧情：2000 tokens input + 500 tokens output
- 判定逻辑：1000 tokens input + 100 tokens output

**计算**（1000 次对话）：
```
生成成本 = (2000 × $0.65 + 500 × $2.75) / 1,000,000 × 1000
        = ($1.30 + $1.375) × 1000 / 1000
        = $2.675

判定成本 = (1000 × $0.05 + 100 × $0.25) / 1,000,000 × 1000
        = ($0.05 + $0.025) × 1000 / 1000
        = $0.075

总计：$2.75 / 1000次对话
```

**月成本估算**：
| 日活用户 | 每日对话 | 月对话数 | 月成本 |
|---------|---------|---------|--------|
| 10 | 20 | 6,000 | $16.5 |
| 50 | 20 | 30,000 | $82.5 |
| 100 | 20 | 60,000 | $165 |
| 500 | 20 | 300,000 | $825 |

#### 方案 B：混合方案（推荐）

**模型选择**：
- 80% 普通场景：Llama 3.1 70B (Replicate)
- 20% 重要场景：Claude 3.5 Sonnet (直接 API)
- 判定：Mistral 7B (Replicate)

**计算**（1000 次对话）：
```
普通场景 (800次) = $2.75 × 0.8 = $2.20
重要场景 (200次) = $13.5 × 0.2 = $2.70
判定 (1000次) = $0.075

总计：$4.975 / 1000次对话
```

**月成本估算**：
| 日活用户 | 月成本 |
|---------|--------|
| 10 | $29.85 |
| 50 | $149.25 |
| 100 | $298.5 |
| 500 | $1,492.5 |

### 2. 服务器成本

#### 方案 A：Fly.io（推荐）

**配置**：
- Web Server: 2 CPU, 2GB RAM × 1 实例
- Worker: 2 CPU, 2GB RAM × 2 实例
- Redis: 256MB

**价格**：
```
Web: $15/月
Worker: $15 × 2 = $30/月
Redis: $5/月

总计：$50/月
```

**扩展**（100+ 日活）：
```
Web: $15 × 2 = $30/月
Worker: $15 × 4 = $60/月
Redis: $10/月

总计：$100/月
```

#### 方案 B：Railway

**价格**：约 $20-40/月（类似 Fly.io）

#### 方案 C：自建 VPS（最便宜）

**Hetzner CPX21**：
- 3 vCPU, 4GB RAM
- 80GB SSD
- 价格：€5.83/月 ≈ $6.5/月

**可以运行**：
- Web Server (FastAPI)
- 3-4 个 Worker
- Redis
- PostgreSQL（或使用 Supabase 免费版）

**总计**：$6.5/月

### 3. 数据库成本

#### Supabase（推荐）

**Free Plan**：
- ✅ 500MB 数据库
- ✅ 1GB 文件存储
- ✅ 50,000 月活用户
- ✅ 500,000 Edge Function 调用
- **成本：$0**

**Pro Plan**（超出免费额度）：
- 8GB 数据库
- 100GB 文件存储
- **成本：$25/月**

### 4. 向量数据库成本（角色知识库）

#### 方案 A：Supabase Vector（推荐）

**使用 pgvector 扩展**：
- ✅ 免费（包含在 Supabase 中）
- ✅ 无需额外服务
- ✅ 适合中小规模（< 100万条）

**成本：$0**（使用 Supabase 免费版）

#### 方案 B：Pinecone

**Starter Plan**：
- 1 个索引
- 100,000 向量
- **成本：$0**（免费）

**Standard Plan**：
- 5 个索引
- 10M 向量
- **成本：$70/月**

#### 方案 C：Qdrant Cloud

**Free Plan**：
- 1GB 存储
- 约 100万个向量
- **成本：$0**

### 5. 向量嵌入成本

**生成角色知识库向量**：

假设：
- 每个剧本 10 个角色
- 每个角色 2000 字描述
- 3 个剧本 = 60,000 字

**使用 OpenAI text-embedding-3-small**：
```
成本 = 60,000 tokens × $0.02 / 1,000,000
    = $0.0012

一次性成本：约 $0.001（可忽略）
```

## 二、完整成本表（独立开发者）

### 启动阶段（< 10 日活用户）

| 项目 | 方案 | 月成本 |
|------|------|--------|
| **LLM API** | 纯 Replicate | $16.5 |
| **服务器** | 自建 VPS (Hetzner) | $6.5 |
| **数据库** | Supabase Free | $0 |
| **向量数据库** | Supabase pgvector | $0 |
| **域名** | Cloudflare | $10/年 ≈ $0.83 |
| **SSL** | Let's Encrypt | $0 |
| **监控** | Sentry Free | $0 |
| **总计** | | **$23.83/月** |

### 成长阶段（50 日活用户）

| 项目 | 方案 | 月成本 |
|------|------|--------|
| **LLM API** | 混合方案 | $149.25 |
| **服务器** | Fly.io (1 Web + 2 Worker) | $50 |
| **数据库** | Supabase Pro | $25 |
| **向量数据库** | Supabase pgvector | $0 |
| **CDN** | Cloudflare | $0 |
| **总计** | | **$224.25/月** |

### 扩展阶段（100 日活用户）

| 项目 | 方案 | 月成本 |
|------|------|--------|
| **LLM API** | 混合方案 | $298.5 |
| **服务器** | Fly.io (2 Web + 4 Worker) | $100 |
| **数据库** | Supabase Pro | $25 |
| **向量数据库** | Supabase pgvector | $0 |
| **总计** | | **$423.5/月** |

## 三、成本优化策略

### 1. LLM 成本优化

#### 策略 A：智能路由

```python
class SmartRouter:
    def route_request(self, context):
        # 计算场景重要性
        importance = self.calculate_importance(context)
        
        if importance > 0.8:
            return "claude-3-5-sonnet"  # 重要场景
        elif importance > 0.5:
            return "llama-3.1-70b"  # 中等场景
        else:
            return "mistral-7b"  # 简单场景
    
    def calculate_importance(self, context):
        """根据多个因素计算重要性"""
        score = 0
        
        # 章节开始/结束
        if context.get("is_chapter_boundary"):
            score += 0.3
        
        # 关键剧情点
        if context.get("is_key_plot"):
            score += 0.4
        
        # 用户付费状态
        if context.get("is_premium_user"):
            score += 0.2
        
        # 对话轮次（前几轮更重要）
        if context.get("turn_count") < 5:
            score += 0.1
        
        return min(score, 1.0)
```

**效果**：成本降低 40-60%

#### 策略 B：响应缓存

```python
import hashlib
import redis

class ResponseCache:
    def __init__(self):
        self.redis = redis.Redis()
        self.ttl = 3600 * 24 * 7  # 7天
    
    def get_cached_response(self, prompt):
        """获取缓存的响应"""
        key = self._generate_key(prompt)
        cached = self.redis.get(key)
        if cached:
            return json.loads(cached)
        return None
    
    def cache_response(self, prompt, response):
        """缓存响应"""
        key = self._generate_key(prompt)
        self.redis.setex(
            key,
            self.ttl,
            json.dumps(response)
        )
    
    def _generate_key(self, prompt):
        """生成缓存键"""
        # 对相似的 prompt 生成相同的 key
        normalized = self._normalize_prompt(prompt)
        return f"llm:cache:{hashlib.md5(normalized.encode()).hexdigest()}"
    
    def _normalize_prompt(self, prompt):
        """标准化 prompt（去除用户特定信息）"""
        # 移除用户名、时间戳等
        import re
        prompt = re.sub(r'\d{4}-\d{2}-\d{2}', '', prompt)
        prompt = re.sub(r'用户\w+', '用户', prompt)
        return prompt.lower().strip()

# 使用
cache = ResponseCache()

async def generate_with_cache(prompt):
    # 检查缓存
    cached = cache.get_cached_response(prompt)
    if cached:
        return cached
    
    # 调用 LLM
    response = await call_llm(prompt)
    
    # 缓存结果
    cache.cache_response(prompt, response)
    
    return response
```

**效果**：
- 缓存命中率 20-30%
- 成本降低 20-30%
- 响应速度提升 10倍

#### 策略 C：批量处理

```python
class BatchProcessor:
    def __init__(self, batch_size=10, wait_time=2):
        self.batch_size = batch_size
        self.wait_time = wait_time
        self.queue = []
    
    async def add_request(self, request):
        """添加请求到批次"""
        self.queue.append(request)
        
        if len(self.queue) >= self.batch_size:
            return await self.process_batch()
        
        # 等待更多请求
        await asyncio.sleep(self.wait_time)
        return await self.process_batch()
    
    async def process_batch(self):
        """批量处理请求"""
        if not self.queue:
            return []
        
        batch = self.queue[:self.batch_size]
        self.queue = self.queue[self.batch_size:]
        
        # 批量调用 LLM（某些 API 支持）
        responses = await self.batch_call_llm(batch)
        
        return responses
```

**效果**：
- 并发处理，减少等待时间
- 某些 API 有批量折扣

### 2. 服务器成本优化

#### 策略 A：自动扩缩容

```yaml
# fly.toml
[http_service]
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1
  max_machines_running = 5

[services.concurrency]
  type = "requests"
  soft_limit = 80
  hard_limit = 100
```

**效果**：
- 低峰期自动停机
- 成本降低 30-50%

#### 策略 B：使用 Spot 实例

```bash
# 使用 Hetzner Cloud 的 Spot 实例
# 价格降低 60-70%
```

### 3. 数据库成本优化

#### 策略 A：数据归档

```python
# 定期归档旧数据
async def archive_old_sessions():
    """归档 30 天前的会话"""
    cutoff_date = datetime.now() - timedelta(days=30)
    
    # 导出到 S3/对象存储
    old_sessions = await db.query(
        "SELECT * FROM chat_sessions WHERE created_at < $1",
        cutoff_date
    )
    
    # 保存到便宜的对象存储
    await s3.upload(old_sessions)
    
    # 删除数据库记录
    await db.execute(
        "DELETE FROM chat_sessions WHERE created_at < $1",
        cutoff_date
    )
```

**效果**：
- 数据库大小减少 70-80%
- 保持在免费额度内

#### 策略 B：使用 Supabase 免费版 + 对象存储

```
Supabase Free (500MB) - 存储活跃数据
    ↓
S3/R2 ($0.015/GB) - 存储归档数据
```

## 四、角色知识库方案

### 方案 A：Supabase pgvector（推荐）

```sql
-- 创建向量表
CREATE TABLE character_knowledge (
  id UUID PRIMARY KEY,
  story_id TEXT,
  character_name TEXT,
  content TEXT,
  embedding VECTOR(1536),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 创建向量索引
CREATE INDEX ON character_knowledge 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
```

```python
from supabase import create_client
import openai

# 生成嵌入
def generate_embedding(text):
    response = openai.embeddings.create(
        model="text-embedding-3-small",
        input=text
    )
    return response.data[0].embedding

# 存储角色知识
async def store_character_knowledge(story_id, character_name, content):
    embedding = generate_embedding(content)
    
    await supabase.table("character_knowledge").insert({
        "story_id": story_id,
        "character_name": character_name,
        "content": content,
        "embedding": embedding,
        "metadata": {
            "type": "background",
            "importance": "high"
        }
    }).execute()

# 检索相关知识
async def retrieve_character_knowledge(story_id, query, limit=5):
    query_embedding = generate_embedding(query)
    
    result = await supabase.rpc(
        "match_character_knowledge",
        {
            "query_embedding": query_embedding,
            "match_threshold": 0.7,
            "match_count": limit,
            "story_filter": story_id
        }
    ).execute()
    
    return result.data
```

**SQL 函数**：
```sql
CREATE OR REPLACE FUNCTION match_character_knowledge(
  query_embedding VECTOR(1536),
  match_threshold FLOAT,
  match_count INT,
  story_filter TEXT
)
RETURNS TABLE (
  id UUID,
  character_name TEXT,
  content TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    character_knowledge.id,
    character_knowledge.character_name,
    character_knowledge.content,
    1 - (character_knowledge.embedding <=> query_embedding) AS similarity
  FROM character_knowledge
  WHERE 
    character_knowledge.story_id = story_filter
    AND 1 - (character_knowledge.embedding <=> query_embedding) > match_threshold
  ORDER BY character_knowledge.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

**成本**：
- 存储：免费（Supabase Free）
- 嵌入生成：$0.02/1M tokens（一次性）
- 查询：免费

### 方案 B：本地嵌入模型（零成本）

```python
from sentence_transformers import SentenceTransformer

# 使用开源模型
model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')

# 生成嵌入（完全免费）
embedding = model.encode("角色描述...")

# 存储到 Supabase
```

**优势**：
- ✅ 完全免费
- ✅ 无 API 调用限制
- ✅ 数据隐私

**劣势**：
- 需要在服务器上运行（增加内存）
- 质量略低于 OpenAI

## 五、最终推荐配置（独立开发者）

### 极致省钱方案（< $30/月）

```yaml
LLM:
  生成: Llama 3.1 70B (Replicate)
  判定: Mistral 7B (Replicate)
  成本: ~$17/月 (10 日活)

服务器:
  平台: Hetzner VPS
  配置: 3 vCPU, 4GB RAM
  成本: $6.5/月

数据库:
  平台: Supabase Free
  成本: $0

向量数据库:
  方案: Supabase pgvector
  嵌入: 本地模型 (sentence-transformers)
  成本: $0

总计: ~$24/月
```

### 平衡方案（< $250/月）

```yaml
LLM:
  生成: 80% Llama 3.1 + 20% Claude 3.5
  判定: Mistral 7B
  成本: ~$150/月 (50 日活)

服务器:
  平台: Fly.io
  配置: 1 Web + 2 Worker
  成本: $50/月

数据库:
  平台: Supabase Pro
  成本: $25/月

向量数据库:
  方案: Supabase pgvector
  嵌入: OpenAI text-embedding-3-small
  成本: ~$1/月

缓存: Redis (Fly.io)
  成本: $5/月

CDN: Cloudflare
  成本: $0

总计: ~$231/月
```

## 六、收入模型建议

### 免费 + 订阅制

```
免费版:
- 每日 5 次对话
- 使用 Llama 3.1 70B
- 基础剧情

订阅版 ($9.99/月):
- 无限对话
- 使用 Claude 3.5 Sonnet
- 高质量剧情
- 优先处理
- 保存更多存档

成本: ~$3/用户/月
利润: ~$7/用户/月
```

**盈亏平衡点**：
- 需要 33 个付费用户 ($231 / $7)
- 假设转化率 5%，需要 660 个免费用户

## 七、总结

### 启动建议（前 3 个月）

1. **使用纯 Replicate**（Llama 3.1 70B）
2. **自建 VPS**（Hetzner $6.5/月）
3. **Supabase Free**（数据库 + 向量）
4. **本地嵌入模型**（零成本）

**总成本：< $30/月**

### 成长建议（3-12 个月）

1. **混合 LLM**（Llama + Claude）
2. **Fly.io**（自动扩缩容）
3. **Supabase Pro**（更大容量）
4. **添加缓存**（降低 LLM 成本）

**总成本：$200-300/月**

### 关键指标监控

```python
# 监控每个用户的成本
cost_per_user = total_llm_cost / active_users

# 目标：< $3/用户/月
if cost_per_user > 3:
    # 启用更多优化策略
    enable_aggressive_caching()
    increase_replicate_usage()
```
