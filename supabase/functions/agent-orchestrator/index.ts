/**
 * Agent 协调器 - 整合 ink、记忆、大模型、判定逻辑
 * 这是真正的"大脑"，负责决策和状态管理
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createSupabaseClient } from "../_shared/database.ts";
import { createReplicatePrediction, streamReplicateOutput } from "../_shared/replicate-gpt-5-mini.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface AgentState {
  sessionId: string;
  userId: string;
  storyId: string;
  currentChapter: number;
  currentSituation: string;
  stateVariables: Record<string, number>; // ink 变量状态
  conversationHistory: Array<{ role: string; content: string }>;
}

interface AgentDecision {
  shouldContinue: boolean;
  shouldAdvanceChapter: boolean;
  shouldEndStory: boolean;
  situationUpdate?: {
    situation: string;
    score: number;
    rationale: string;
  };
  stateChanges?: Record<string, number>;
}

/**
 * Agent 核心：协调所有组件
 */
class StoryAgent {
  private supabase;
  private replicateToken: string;
  
  constructor(replicateToken: string) {
    this.supabase = createSupabaseClient();
    this.replicateToken = replicateToken;
  }

  /**
   * 主流程：处理用户输入并返回响应
   */
  async processUserInput(
    state: AgentState,
    userInput: string,
  ): Promise<{
    response: string;
    decision: AgentDecision;
    updatedState: AgentState;
  }> {
    // 1. 从 ink 引擎获取当前剧本状态
    const inkState = await this.getInkState(state);
    
    // 2. 从记忆系统检索相关上下文
    const memories = await this.retrieveMemories(state, userInput);
    
    // 3. 构建提示词，调用大模型生成剧情
    const llmResponse = await this.generateStoryResponse(
      state,
      inkState,
      memories,
      userInput,
    );
    
    // 4. 判定器：评估当前局势，决定是否推进
    const decision = await this.evaluateSituation(
      state,
      inkState,
      llmResponse,
    );
    
    // 5. 更新状态到数据库
    const updatedState = await this.updateState(state, decision, llmResponse);
    
    // 6. 如果需要推进章节，调用 ink 引擎
    if (decision.shouldAdvanceChapter) {
      await this.advanceInkStory(updatedState);
    }
    
    return {
      response: llmResponse,
      decision,
      updatedState,
    };
  }

  /**
   * 步骤1：获取 ink 引擎状态
   */
  private async getInkState(state: AgentState) {
    // 调用 ink-runtime Edge Function
    const response = await fetch(
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/ink-runtime`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          storyId: state.storyId,
          currentChapter: state.currentChapter,
          stateVariables: state.stateVariables,
        }),
      },
    );
    
    const inkState = await response.json();
    return {
      currentText: inkState.text,
      availableChoices: inkState.choices,
      tags: inkState.tags, // 如 #chapter:2 #situation:crisis
      variables: inkState.variables, // ink 中的变量状态
    };
  }

  /**
   * 步骤2：检索相关记忆
   */
  private async retrieveMemories(state: AgentState, query: string) {
    // 从向量数据库检索相关历史事件
    const { data: memories } = await this.supabase
      .from("memory_records")
      .select("*")
      .eq("session_id", state.sessionId)
      .order("created_at", { ascending: false })
      .limit(5);
    
    return memories || [];
  }

  /**
   * 步骤3：调用大模型生成剧情
   */
  private async generateStoryResponse(
    state: AgentState,
    inkState: any,
    memories: any[],
    userInput: string,
  ): Promise<string> {
    // 构建系统提示词
    const systemPrompt = this.buildSystemPrompt(state, inkState, memories);
    
    // 构建消息历史
    const messages = [
      { role: "system", content: systemPrompt },
      ...state.conversationHistory.slice(-10), // 最近10轮对话
      { role: "user", content: userInput },
    ];
    
    // 调用 Replicate
    const streamUrl = await createReplicatePrediction(
      { messages, maxOutputTokens: 1024, reasoningEffort: "medium" },
      this.replicateToken,
    );
    
    let fullResponse = "";
    for await (const delta of streamReplicateOutput(streamUrl, this.replicateToken)) {
      fullResponse += delta;
    }
    
    return fullResponse;
  }

  /**
   * 步骤4：判定器 - 评估是否推进剧情
   */
  private async evaluateSituation(
    state: AgentState,
    inkState: any,
    llmResponse: string,
  ): Promise<AgentDecision> {
    // 调用判定模型（可以是另一个 LLM 调用）
    const judgmentPrompt = `
你是剧情判定器。根据以下信息判断剧情进展：

当前章节：${state.currentChapter}
当前局势：${state.currentSituation}
ink 状态变量：${JSON.stringify(state.stateVariables)}
最新剧情：${llmResponse}

请判断：
1. 当前局势是否完成（0-100分）
2. 是否应该进入下一章节
3. 是否应该结束故事

返回 JSON 格式：
{
  "situationScore": 85,
  "shouldAdvanceChapter": true,
  "shouldEndStory": false,
  "rationale": "玩家成功解决了边疆危机，应该进入下一章节",
  "stateChanges": {
    "ming_years": 3,
    "treasury": -50
  }
}
`;

    const messages = [{ role: "user", content: judgmentPrompt }];
    const streamUrl = await createReplicatePrediction(
      { messages, maxOutputTokens: 512, reasoningEffort: "low" },
      this.replicateToken,
    );
    
    let judgmentText = "";
    for await (const delta of streamReplicateOutput(streamUrl, this.replicateToken)) {
      judgmentText += delta;
    }
    
    // 解析 JSON（需要容错处理）
    try {
      const judgment = JSON.parse(judgmentText);
      return {
        shouldContinue: judgment.situationScore < 100,
        shouldAdvanceChapter: judgment.shouldAdvanceChapter,
        shouldEndStory: judgment.shouldEndStory,
        situationUpdate: {
          situation: state.currentSituation,
          score: judgment.situationScore,
          rationale: judgment.rationale,
        },
        stateChanges: judgment.stateChanges,
      };
    } catch (e) {
      // 解析失败，使用默认判定
      return {
        shouldContinue: true,
        shouldAdvanceChapter: false,
        shouldEndStory: false,
      };
    }
  }

  /**
   * 步骤5：更新状态到数据库
   */
  private async updateState(
    state: AgentState,
    decision: AgentDecision,
    response: string,
  ): Promise<AgentState> {
    // 保存对话消息
    await this.supabase.from("chat_messages").insert([
      { session_id: state.sessionId, role: "user", content: state.conversationHistory[state.conversationHistory.length - 1].content },
      { session_id: state.sessionId, role: "assistant", content: response },
    ]);
    
    // 更新局势状态
    if (decision.situationUpdate) {
      await this.supabase.from("situation_states").insert({
        session_id: state.sessionId,
        situation_id: state.currentSituation,
        completion_score: decision.situationUpdate.score,
        rationale: decision.situationUpdate.rationale,
      });
    }
    
    // 更新状态变量
    if (decision.stateChanges) {
      const newVariables = { ...state.stateVariables, ...decision.stateChanges };
      await this.supabase.from("session_state").upsert({
        session_id: state.sessionId,
        state_variables: newVariables,
      });
      
      state.stateVariables = newVariables;
    }
    
    // 如果推进章节
    if (decision.shouldAdvanceChapter) {
      state.currentChapter += 1;
      await this.supabase.from("chat_sessions").update({
        current_chapter: state.currentChapter,
      }).eq("id", state.sessionId);
    }
    
    return state;
  }

  /**
   * 步骤6：推进 ink 剧本
   */
  private async advanceInkStory(state: AgentState) {
    // 调用 ink-runtime 推进到下一个节点
    await fetch(
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/ink-runtime/advance`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          storyId: state.storyId,
          currentChapter: state.currentChapter,
          stateVariables: state.stateVariables,
        }),
      },
    );
  }

  /**
   * 构建系统提示词
   */
  private buildSystemPrompt(state: AgentState, inkState: any, memories: any[]): string {
    const memoryContext = memories.map(m => m.summary).join("\n");
    
    return `你是${state.storyId}剧本的叙事者。

当前章节：第${state.currentChapter}章
当前局势：${state.currentSituation}
剧本描述：${inkState.currentText}

状态变量：
${JSON.stringify(state.stateVariables, null, 2)}

历史记忆：
${memoryContext}

请根据玩家的选择，生成生动的剧情描述。注意：
1. 保持角色一致性
2. 根据状态变量调整剧情
3. 为玩家提供有意义的选择
4. 推动剧情向前发展`;
  }
}

/**
 * Edge Function 入口
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  
  const replicateToken = Deno.env.get("REPLICATE_API_TOKEN");
  if (!replicateToken) {
    return new Response("缺少 REPLICATE_API_TOKEN", { status: 500, headers: corsHeaders });
  }
  
  const { sessionId, userId, storyId, userInput } = await req.json();
  
  // 加载当前会话状态
  const supabase = createSupabaseClient();
  const { data: session } = await supabase
    .from("chat_sessions")
    .select("*")
    .eq("id", sessionId)
    .single();
  
  if (!session) {
    return new Response("会话不存在", { status: 404, headers: corsHeaders });
  }
  
  // 构建 Agent 状态
  const state: AgentState = {
    sessionId,
    userId,
    storyId,
    currentChapter: session.current_chapter || 1,
    currentSituation: session.current_situation || "initial",
    stateVariables: session.state_variables || {},
    conversationHistory: [], // 从数据库加载
  };
  
  // 创建 Agent 并处理
  const agent = new StoryAgent(replicateToken);
  const result = await agent.processUserInput(state, userInput);
  
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
});
