/**
 * Replicate API 通用调用工具
 * 提供流式和非流式调用方法
 */

export interface ReplicateMessage {
  role: string;
  content: string;
}

export interface ReplicateStreamOptions {
  messages: ReplicateMessage[];
  maxOutputTokens?: number;
  reasoningEffort?: "low" | "medium" | "high";
}

/**
 * 流式读取 Replicate 输出
 */
export async function* streamReplicateOutput(
  streamUrl: string,
  replicateToken: string,
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
          if (data === "{}") continue;
          
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

/**
 * 创建 Replicate 预测并返回流 URL
 */
export async function createReplicatePrediction(
  options: ReplicateStreamOptions,
  replicateToken: string,
): Promise<string> {
  const input = {
    messages: options.messages,
    max_output_tokens: options.maxOutputTokens || 1024,
    reasoning_effort: options.reasoningEffort || "medium",
  };

  const response = await fetch(
    "https://api.replicate.com/v1/models/openai/gpt-5-mini/predictions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${replicateToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ 
        input,
        stream: true,
      }),
    }
  );
  
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`创建预测失败: ${response.status} ${errorText}`);
  }

  const payload = await response.json();
  const streamUrl = payload?.urls?.stream as string | undefined;
  
  if (!streamUrl) {
    throw new Error("模型不支持流式输出或无法获取流 URL");
  }

  return streamUrl;
}

/**
 * 从 Replicate 响应中提取输出文本
 */
export function extractReply(payload: Record<string, unknown>): string {
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
