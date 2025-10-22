/**
 * 赛博朋克 2177 剧本专用 Edge Function
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

const CYBERPUNK_FORMAT_INSTRUCTION: ReplicateMessage = {
  role: "system",
  content:
    "你是赛博朋克世界的AI助手。请用中文输出，按照以下格式组织回复：\n\n🌃 环境：<描述当前场景，突出科技感和霓虹氛围>\n\n💻 情报：<详细描述事件发展和线索，至少两段>\n\n⚡ 行动：<提供2-3个可选的调查或行动方向>\n\n请保持赛博朋克风格，注重科技、阴谋和人性的冲突。",
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
  const formattedMessages = [CYBERPUNK_FORMAT_INSTRUCTION, ...messages];

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
