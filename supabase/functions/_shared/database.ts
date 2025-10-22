/**
 * 数据库操作通用工具
 */

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.1";

export interface ChatMessage {
  session_id: string;
  role: string;
  content: string;
}

/**
 * 创建 Supabase 客户端
 */
export function createSupabaseClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error("缺少 Supabase 配置");
  }
  
  return createClient(supabaseUrl, supabaseServiceRoleKey);
}

/**
 * 保存用户消息到数据库
 */
export async function saveUserMessage(
  supabase: SupabaseClient,
  sessionId: string,
  content: string,
): Promise<void> {
  await supabase.from('chat_messages').insert({
    session_id: sessionId,
    role: 'user',
    content,
  });
}

/**
 * 保存 AI 回复到数据库
 */
export async function saveAssistantMessage(
  supabase: SupabaseClient,
  sessionId: string,
  content: string,
): Promise<void> {
  await supabase.from('chat_messages').insert({
    session_id: sessionId,
    role: 'assistant',
    content,
  });
}
