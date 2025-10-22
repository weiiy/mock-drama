/**
 * 魔法学院剧本专用 Edge Function
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

const FANTASY_FORMAT_INSTRUCTION: ReplicateMessage = {
  role: "system",
  content:
    "你是阿卡纳魔法学院的导师。请用中文输出，按照以下格式组织回复：\n\n✨ 场景：<描述当前场景和氛围>\n\n📜 剧情：<详细描述事件发展，至少两段>\n\n🎯 选项：<提供2-3个可选的行动方案>\n\n请保持奇幻风格，注重魔法世界的细节描写。",
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
  const formattedMessages = [FANTASY_FORMAT_INSTRUCTION, ...messages];

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
