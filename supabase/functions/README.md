# Edge Functions 架构说明

## 架构设计

本项目采用**模块化架构**，将通用逻辑和剧本特定逻辑分离：

### 1. 共享模块 (`_shared/`)

#### `replicate.ts`
- **功能**：Replicate API 通用调用工具
- **导出**：
  - `streamReplicateOutput()` - 流式读取 Replicate 输出
  - `createReplicatePrediction()` - 创建预测并返回流 URL
  - `extractReply()` - 提取响应文本
  - `ReplicateMessage` 类型定义

#### `database.ts`
- **功能**：Supabase 数据库操作工具
- **导出**：
  - `createSupabaseClient()` - 创建 Supabase 客户端
  - `saveUserMessage()` - 保存用户消息
  - `saveAssistantMessage()` - 保存 AI 回复

### 2. 剧本特定函数

每个剧本都有独立的 Edge Function，负责：
- 定义剧本特定的格式化指令（`formatInstruction`）
- 处理剧本特定的输出格式化逻辑
- 调用共享工具完成 API 调用和数据库操作

#### 已实现的剧本函数：

| 函数名 | 剧本 | 格式化特点 |
|--------|------|-----------|
| `chongzhen` | 崇祯皇帝 | 包含"回复""📖剧情""📊成果""💡提示"四个标签 |
| `fantasy` | 魔法学院 | 包含"✨场景""📜剧情""🎯选项"三个标签 |
| `cyberpunk` | 赛博朋克 2177 | 包含"🌃环境""💻情报""⚡行动"三个标签 |

### 3. 通用接口 (`orchestrator`)

- **用途**：可选的通用接口，支持客户端传递自定义 `formatInstruction`
- **适用场景**：快速测试、动态剧本、不需要特殊格式化的场景

## 部署步骤

### 1. 部署共享模块
共享模块无需单独部署，会被其他函数自动引用。

### 2. 部署剧本函数

```bash
# 部署崇祯剧本函数
supabase functions deploy chongzhen

# 部署魔法学院剧本函数
supabase functions deploy fantasy

# 部署赛博朋克剧本函数
supabase functions deploy cyberpunk

# 部署通用接口（可选）
supabase functions deploy orchestrator
```

### 3. 一次性部署所有函数

```bash
# 部署所有函数
supabase functions deploy chongzhen fantasy cyberpunk orchestrator
```

## 客户端调用

Flutter 客户端会根据剧本的 `edgeFunctionName` 字段自动调用对应的 Edge Function：

```dart
// 剧本数据模型
Story(
  id: 'chongzhen',
  title: '崇祯皇帝',
  edgeFunctionName: 'chongzhen',  // 对应的 Edge Function
  // ...
)

// 调用时自动使用对应的函数
final url = Uri.parse('$supabaseUrl/functions/v1/${widget.story.edgeFunctionName}');
```

## 添加新剧本

### 1. 创建新的 Edge Function

在 `supabase/functions/` 下创建新文件夹，例如 `my_story/index.ts`：

```typescript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { 
  streamReplicateOutput, 
  createReplicatePrediction,
  type ReplicateMessage 
} from "../_shared/replicate.ts";
import { 
  createSupabaseClient,
  saveUserMessage,
  saveAssistantMessage 
} from "../_shared/database.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const replicateToken = Deno.env.get("REPLICATE_API_TOKEN");

// 定义剧本特定的格式化指令
const MY_STORY_FORMAT_INSTRUCTION: ReplicateMessage = {
  role: "system",
  content: "你的剧本特定提示词...",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }
  if (!replicateToken) {
    return new Response("缺少 REPLICATE_API_TOKEN", { status: 500, headers: corsHeaders });
  }
  
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response("请求体需为 JSON", { status: 400, headers: corsHeaders });
  }
  
  const bodyObj = body as Record<string, unknown>;
  const messages = bodyObj.messages as ReplicateMessage[] | undefined;
  const sessionId = bodyObj.sessionId as string | undefined;
  const userId = bodyObj.userId as string | undefined;
  
  if (!Array.isArray(messages)) {
    return new Response("缺少 messages 数组", { status: 400, headers: corsHeaders });
  }
  
  const supabase = createSupabaseClient();
  const formattedMessages = [MY_STORY_FORMAT_INSTRUCTION, ...messages];

  const userMessage = messages[messages.length - 1];
  if (sessionId && userId && userMessage && userMessage.role === 'user') {
    await saveUserMessage(supabase, sessionId, userMessage.content);
  }

  const streamUrl = await createReplicatePrediction(
    { messages: formattedMessages, maxOutputTokens: 1024, reasoningEffort: "medium" },
    replicateToken,
  );

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      let rawOutput = "";
      
      try {
        for await (const delta of streamReplicateOutput(streamUrl, replicateToken)) {
          rawOutput += delta;
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({ delta })}\n\n`));
        }
        
        // 可选：添加剧本特定的格式化处理
        // const formatted = formatMyStoryOutput(rawOutput);
        
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({ final: rawOutput })}\n\n`));
        
        if (sessionId && userId && rawOutput) {
          await saveAssistantMessage(supabase, sessionId, rawOutput);
        }
        
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
      } catch (error) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({ error: String(error) })}\n\n`));
      } finally {
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      ...corsHeaders,
    },
  });
});
```

### 2. 在 Flutter 中添加剧本

在 `app/lib/main.dart` 的 `availableStories` 列表中添加：

```dart
Story(
  id: 'my_story',
  title: '我的剧本',
  description: '剧本描述...',
  coverImage: '🎭',
  systemPrompt: '系统提示词...',
  tags: ['标签1', '标签2'],
  edgeFunctionName: 'my_story',  // 对应 Edge Function 名称
),
```

### 3. 部署新函数

```bash
supabase functions deploy my_story
```

## 优势

✅ **关注点分离**：通用逻辑和剧本逻辑解耦  
✅ **易于扩展**：添加新剧本只需创建新函数  
✅ **代码复用**：共享模块避免重复代码  
✅ **独立部署**：每个剧本可独立更新  
✅ **类型安全**：TypeScript 类型定义  
✅ **易于维护**：清晰的模块结构

## 注意事项

1. **环境变量**：确保设置了 `REPLICATE_API_TOKEN`
2. **CORS 配置**：所有函数都已配置 CORS 头
3. **错误处理**：统一的错误处理机制
4. **流式响应**：支持 SSE (Server-Sent Events)
