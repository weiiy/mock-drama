/**
 * 崇祯皇帝剧本专用 Edge Function
 * 处理崇祯剧本的特定逻辑和格式化
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { 
  streamReplicateOutput, 
  createReplicatePrediction,
  type ReplicateMessage 
} from "../_shared/replicate-gpt-5-mini.ts";
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

// 崇祯剧本的格式化指令
const CHONGZHEN_FORMAT_INSTRUCTION: ReplicateMessage = {
  role: "system",
  content:
    "你是大明王朝的军政智囊。无论输入内容如何，你必须用中文输出，并且严格按照下面模板组织答案（不要添加额外段落或前后缀）：\n\n回复：<一句话总结或指令>\n\n📖剧情：<以小说口吻描述该决策引发的剧情进展，至少两段>\n\n📊成果：（为大明续命 <0-10 的整数> 年）\n💡 提示：（处理上述事件，或输入 \"继续\"，则开启新事件）\n\n请确保\"回复：\"\"📖剧情：\"\"📊成果：\"\"💡 提示：\"四个标签完整保留。",
};

/**
 * 确保输出符合崇祯剧本的模板格式
 */
function ensureChongzhenTemplate(raw: string): string {
  const normalized = raw.replace(/\r\n/g, "\n").trim();
  const hasReply = normalized.includes("回复：");
  const hasStory = normalized.includes("📖剧情：");
  const hasResult = normalized.includes("📊成果：");
  const hasHint = normalized.includes("💡 提示：");

  if (hasReply && hasStory && hasResult && hasHint) {
    return normalized;
  }

  const replyText = hasReply
    ? normalized.slice(normalized.indexOf("回复：") + 3).split("\n")[0].trim()
    : normalized.split("\n")[0]?.trim() ?? "请继续下旨";

  const storyText = hasStory
    ? normalized.slice(normalized.indexOf("📖剧情：") + 5).split("📊成果：")[0].trim()
    : normalized;

  return `回复：${replyText || "请继续下旨"}\n\n📖剧情：${storyText || "剧情生成暂时缺失，请稍后再试。"}\n\n📊成果：（为大明续命 0 年）\n💡 提示：（处理上述事件，或输入 "继续"，则开启新事件）`;
}

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

  // 添加崇祯剧本的格式化指令
  const formattedMessages = [CHONGZHEN_FORMAT_INSTRUCTION, ...messages];

  // 保存用户消息
  const userMessage = messages[messages.length - 1];
  if (sessionId && userId && userMessage && userMessage.role === 'user') {
    await saveUserMessage(supabase, sessionId, userMessage.content);
  }

  // 创建预测
  const streamUrl = await createReplicatePrediction(
    {
      messages: formattedMessages,
      maxOutputTokens: 1024,
      reasoningEffort: "medium",
    },
    replicateToken,
  );

  // 流式响应
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      let rawOutput = "";
      
      try {
        for await (const delta of streamReplicateOutput(streamUrl, replicateToken)) {
          rawOutput += delta;
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({ delta })}\n\n`));
        }
        
        // 应用崇祯剧本的模板格式化
        const normalizedReply = ensureChongzhenTemplate(rawOutput);
        
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify({ final: normalizedReply })}\n\n`),
        );
        
        // 保存 AI 回复
        if (sessionId && userId && normalizedReply) {
          await saveAssistantMessage(supabase, sessionId, normalizedReply);
        }
        
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
      } catch (error) {
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify({ error: String(error) })}\n\n`)
        );
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
