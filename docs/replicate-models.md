# Replicate 平台模型使用指南

## Replicate 支持的推荐模型

### ✅ 可用模型

#### 1. **Meta Llama 3.1 系列** ⭐⭐⭐⭐⭐
```python
# Llama 3.1 70B Instruct
model = "meta/meta-llama-3.1-70b-instruct"

# Llama 3.1 405B Instruct (最强)
model = "meta/meta-llama-3.1-405b-instruct"
```

**特点**：
- ✅ 开源免费
- ✅ 中文能力不错
- ✅ 故事生成能力强
- ✅ 价格便宜

**价格**（Replicate）：
- 70B: $0.65/1M input, $2.75/1M output
- 405B: $9.5/1M input, $9.5/1M output

**推荐**：70B 版本性价比最高

#### 2. **Mistral 系列** ⭐⭐⭐⭐
```python
# Mistral 7B Instruct
model = "mistralai/mistral-7b-instruct-v0.2"

# Mixtral 8x7B
model = "mistralai/mixtral-8x7b-instruct-v0.1"
```

**特点**：
- ✅ 速度快
- ✅ 价格便宜
- ✅ 多语言支持

**价格**：
- 7B: $0.05/1M input, $0.25/1M output
- 8x7B: $0.3/1M input, $1/1M output

#### 3. **Qwen 系列** (阿里通义千问) ⭐⭐⭐⭐⭐
```python
# Qwen2.5 72B
model = "qwen/qwen2.5-72b-instruct"
```

**特点**：
- ✅ 中文能力极强
- ✅ 历史文化知识丰富
- ✅ 适合中国历史剧本

**价格**：
- 约 $0.5/1M input, $1.5/1M output

### ❌ Replicate 不支持的模型

- ❌ **Claude 系列**（需要直接调用 Anthropic API）
- ❌ **GPT-4o 系列**（需要直接调用 OpenAI API）
- ❌ **Gemini 系列**（需要直接调用 Google API）
- ❌ **DeepSeek**（需要直接调用 DeepSeek API）

## 推荐方案：混合使用

### 方案 A：纯 Replicate（最简单）

```python
# 使用 Llama 3.1 70B
model = "meta/meta-llama-3.1-70b-instruct"

# 生成剧情
story_response = replicate.run(
    model,
    input={
        "prompt": story_prompt,
        "max_tokens": 1024
    }
)

# 判定逻辑（使用更小的模型）
judge_response = replicate.run(
    "mistralai/mistral-7b-instruct-v0.2",
    input={
        "prompt": judge_prompt,
        "max_tokens": 256
    }
)
```

**成本**（1000次对话）：
- 生成：$2.75 × 0.5M = $1.375
- 判定：$0.25 × 0.25M = $0.0625
- **总计：约 $1.44**

### 方案 B：Replicate + 直接 API（推荐）

```python
class HybridLLM:
    def __init__(self):
        self.replicate_model = "meta/meta-llama-3.1-70b-instruct"
        self.claude_client = anthropic.Anthropic()
    
    async def generate_story(self, prompt):
        """重要剧情用 Claude（质量高）"""
        if self.is_important_scene(prompt):
            return await self.call_claude(prompt)
        else:
            # 普通对话用 Replicate（便宜）
            return await self.call_replicate(prompt)
    
    async def judge_situation(self, context):
        """判定用 Replicate（便宜）"""
        return await self.call_replicate(context)
```

**成本**（1000次对话，20%重要场景）：
- Claude（200次）：$3
- Replicate（800次）：$1.15
- **总计：约 $4.15**

### 方案 C：完全使用直接 API（质量最高）

```python
# Claude 生成 + GPT-4o-mini 判定
story = await claude.generate()  # $7.5/1000次
decision = await gpt4o_mini.judge()  # $0.3/1000次
# 总计：$7.8/1000次
```

## Replicate 使用示例

```python
import replicate

# 方式1：同步调用
output = replicate.run(
    "meta/meta-llama-3.1-70b-instruct",
    input={
        "prompt": "你是崇祯皇帝...",
        "max_tokens": 1024,
        "temperature": 0.7,
        "top_p": 0.9
    }
)

# 方式2：流式输出
for event in replicate.stream(
    "meta/meta-llama-3.1-70b-instruct",
    input={"prompt": "..."}
):
    print(event, end="")

# 方式3：异步调用
import asyncio

async def generate():
    output = await replicate.async_run(
        "meta/meta-llama-3.1-70b-instruct",
        input={"prompt": "..."}
    )
    return output
```

## 统一接口封装

```python
class UnifiedLLM:
    """统一不同 LLM 的接口"""
    
    def __init__(self):
        self.replicate_client = replicate.Client()
        self.anthropic_client = anthropic.Anthropic()
        self.openai_client = openai.OpenAI()
    
    async def generate(
        self,
        prompt: str,
        provider: str = "replicate",
        model: str = None
    ):
        if provider == "replicate":
            return await self._call_replicate(prompt, model)
        elif provider == "anthropic":
            return await self._call_claude(prompt, model)
        elif provider == "openai":
            return await self._call_openai(prompt, model)
    
    async def _call_replicate(self, prompt, model):
        model = model or "meta/meta-llama-3.1-70b-instruct"
        return await self.replicate_client.async_run(
            model,
            input={"prompt": prompt, "max_tokens": 1024}
        )
    
    async def _call_claude(self, prompt, model):
        model = model or "claude-3-5-sonnet-20241022"
        response = await self.anthropic_client.messages.create(
            model=model,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )
        return response.content[0].text
    
    async def _call_openai(self, prompt, model):
        model = model or "gpt-4o-mini"
        response = await self.openai_client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}]
        )
        return response.choices[0].message.content

# 使用
llm = UnifiedLLM()

# 普通场景用 Replicate
story = await llm.generate(prompt, provider="replicate")

# 重要场景用 Claude
important_story = await llm.generate(prompt, provider="anthropic")
```

## 推荐配置

### 独立开发者（成本敏感）

```python
# 配置
STORY_MODEL = "meta/meta-llama-3.1-70b-instruct"  # Replicate
JUDGE_MODEL = "mistralai/mistral-7b-instruct-v0.2"  # Replicate

# 成本：约 $1.5/1000次对话
```

### 追求质量

```python
# 配置
STORY_MODEL = "claude-3-5-sonnet"  # Anthropic API
JUDGE_MODEL = "gpt-4o-mini"  # OpenAI API

# 成本：约 $7.8/1000次对话
```

### 平衡方案（推荐）

```python
# 配置
STORY_MODEL_PRIMARY = "meta/meta-llama-3.1-70b-instruct"  # Replicate
STORY_MODEL_PREMIUM = "claude-3-5-sonnet"  # 重要场景
JUDGE_MODEL = "mistralai/mistral-7b-instruct-v0.2"  # Replicate

# 成本：约 $2-4/1000次对话
```

## 总结

| 方案 | 提供商 | 模型 | 成本/1000次 | 质量 |
|------|--------|------|------------|------|
| **纯 Replicate** | Replicate | Llama 3.1 70B | $1.44 | ⭐⭐⭐⭐ |
| **混合方案** | Replicate + Claude | 80% Llama + 20% Claude | $4.15 | ⭐⭐⭐⭐⭐ |
| **纯直接 API** | Anthropic + OpenAI | Claude + GPT-4o-mini | $7.80 | ⭐⭐⭐⭐⭐ |

**推荐**：混合方案，根据场景重要性动态选择模型。
