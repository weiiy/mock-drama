import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const replicateToken = Deno.env.get("REPLICATE_API_TOKEN");
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function* streamReplicateOutput(
  streamUrl: string,
): AsyncGenerator<string, void, unknown> {
  const response = await fetch(streamUrl, {
    headers: {
      Authorization: `Bearer ${replicateToken}`,
      Accept: "text/event-stream",
    },
  });

  if (!response.ok) {
    throw new Error(`Stream fetch failed: ${response.status}`);
  }

  if (!response.body) {
    throw new Error("No response body");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line || line.startsWith(":")) {
          continue;
        }
        if (line.startsWith("event:")) {
          continue;
        }
        if (line.startsWith("data: ")) {
          const data = line.slice(6);
          if (data === "{}") continue; // done event
          
          try {
            const parsed = JSON.parse(data);
            if (parsed.reason || parsed.event === "done") continue;
          } catch {
            // 纯文本数据 - 这是增量内容
            yield data;
          }
        }
      }
    }
  } finally {
    reader.releaseLock();
  }
}

function extractReply(payload: Record<string, unknown>): string {
  const output = payload.output;
  if (typeof output === "string") {
    return output;
  }
  if (Array.isArray(output) && output.length > 0) {
    if (output.every((item) => typeof item === "string")) {
      return (output as string[]).join("");
    }
    const last = output[output.length - 1];
    if (typeof last === "string") {
      return last;
    }
    if (last && typeof last === "object" && "content" in last) {
      const content = (last as Record<string, unknown>).content;
      if (Array.isArray(content) && content.length > 0) {
        const piece = content[0];
        if (piece && typeof piece === "object" && "text" in piece) {
          return String((piece as Record<string, unknown>).text ?? "");
        }
      }
    }
  }
  if (payload.logs && typeof payload.logs === "string" && payload.logs.trim().length > 0) {
    return payload.logs as string;
  }
  return "未获取到模型输出";
}

function ensureTemplate(raw: string): string {
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

  return `回复：${replyText || "请继续下旨"}\n\n📖剧情：${storyText || "剧情生成暂时缺失，请稍后再试。"}\n\n📊成果：（为大明续命 0 年）\n💡 提示：（处理上述事件，或输入 “继续”，则开启新事件）`;
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
  const messages = bodyObj.messages;
  const sessionId = bodyObj.sessionId as string | undefined;
  const userId = bodyObj.userId as string | undefined;
  
  if (!Array.isArray(messages)) {
    return new Response("缺少 messages 数组", { status: 400, headers: corsHeaders });
  }
  
  // 初始化 Supabase 客户端
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

  const formatInstruction = {
    role: "system",
    content:
      "你是大明王朝的军政智囊。无论输入内容如何，你必须用中文输出，并且严格按照下面模板组织答案（不要添加额外段落或前后缀）：\n\n回复：<一句话总结或指令>\n\n📖剧情：<以小说口吻描述该决策引发的剧情进展，至少两段>\n\n📊成果：（为大明续命 <0-10 的整数> 年）\n💡 提示：（处理上述事件，或输入 “继续”，则开启新事件）\n\n请确保“回复：”“📖剧情：”“📊成果：”“💡 提示：”四个标签完整保留。",
  } satisfies { role: string; content: string };

  const formattedMessages = [formatInstruction, ...messages];

  const input = {
    messages: formattedMessages,
    max_output_tokens: 1024,
    reasoning_effort: "medium",
  };

  // 保存用户消息到数据库
  const userMessage = messages[messages.length - 1];
  if (sessionId && userId && userMessage && userMessage.role === 'user') {
    await supabase.from('chat_messages').insert({
      session_id: sessionId,
      role: 'user',
      content: userMessage.content,
    });
  }

  const creation = await fetch("https://api.replicate.com/v1/models/openai/gpt-5-mini/predictions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${replicateToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ 
      input,
      stream: true, // 启用流式输出
    }),
  });
  
  if (!creation.ok) {
    const errorText = await creation.text();
    return new Response(`创建预测失败: ${creation.status} ${errorText}`, {
      status: 502,
      headers: corsHeaders,
    });
  }

  const createdPayload = await creation.json();
  const streamUrl = createdPayload?.urls?.stream as string | undefined;
  
  if (!streamUrl) {
    return new Response("模型不支持流式输出或无法获取流 URL", { status: 502, headers: corsHeaders });
  }

  // 使用流式响应
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      let rawOutput = "";
      
      try {
        for await (const delta of streamReplicateOutput(streamUrl)) {
          rawOutput += delta;
          
          // 将增量内容推送给客户端
          const data = `data: ${JSON.stringify({ delta })}\n\n`;
          controller.enqueue(encoder.encode(data));
        }
        
        const normalizedReply = ensureTemplate(rawOutput);

        // 推送最终格式化结果
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify({ final: normalizedReply })}\n\n`),
        );
        
        // 保存 AI 回复到数据库
        if (sessionId && userId && normalizedReply) {
          await supabase.from('chat_messages').insert({
            session_id: sessionId,
            role: 'assistant',
            content: normalizedReply,
          });
        }
        
        // 发送结束标记
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
      } catch (error) {
        const errorMsg = `data: ${JSON.stringify({ error: String(error) })}\n\n`;
        controller.enqueue(encoder.encode(errorMsg));
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
