/**
 * ink 运行时 - 管理剧本状态和分支逻辑
 * 使用 inkjs 解析和执行 ink 剧本
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
// @deno-types="https://esm.sh/v135/inkjs@2.2.3/engine/Story.d.ts"
import { Story } from "https://esm.sh/inkjs@2.2.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// 缓存已加载的剧本
const storyCache = new Map<string, any>();

/**
 * 加载 ink 剧本 JSON
 */
async function loadStoryJson(storyId: string): Promise<any> {
  if (storyCache.has(storyId)) {
    return storyCache.get(storyId);
  }
  
  // 从 Supabase Storage 或数据库加载编译好的 ink JSON
  // 这里简化为直接返回示例
  const inkJson = {
    "inkVersion": 21,
    "root": [
      ["^崇祯元年，天启皇帝暴毙，你仓促即位。", "\n", ["ev", {"^->": "chapter_1.0.2.$r1"}, {"temp=": "()"}]],
      // ... ink 编译后的 JSON 结构
    ],
    "listDefs": {}
  };
  
  storyCache.set(storyId, inkJson);
  return inkJson;
}

/**
 * 创建或恢复 ink Story 实例
 */
function createStory(inkJson: any, stateVariables?: Record<string, any>): Story {
  const story = new Story(inkJson);
  
  // 恢复状态变量
  if (stateVariables) {
    for (const [key, value] of Object.entries(stateVariables)) {
      try {
        story.variablesState.$(key, value);
      } catch (e) {
        console.warn(`无法设置变量 ${key}:`, e);
      }
    }
  }
  
  return story;
}

/**
 * 解析 ink 标签
 */
function parseTags(tags: string[]): {
  chapter?: number;
  situation?: string;
  metadata: Record<string, string>;
} {
  const result: any = { metadata: {} };
  
  for (const tag of tags) {
    if (tag.startsWith("chapter:")) {
      result.chapter = parseInt(tag.split(":")[1]);
    } else if (tag.startsWith("situation:")) {
      result.situation = tag.split(":")[1];
    } else {
      const [key, value] = tag.split(":");
      if (key && value) {
        result.metadata[key] = value;
      }
    }
  }
  
  return result;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  
  try {
    const { storyId, currentChapter, stateVariables, choiceIndex } = await req.json();
    
    // 加载剧本
    const inkJson = await loadStoryJson(storyId);
    const story = createStory(inkJson, stateVariables);
    
    // 如果提供了选择索引，执行选择
    if (choiceIndex !== undefined && choiceIndex !== null) {
      story.ChooseChoiceIndex(choiceIndex);
    }
    
    // 继续剧本直到下一个选择点
    let fullText = "";
    while (story.canContinue) {
      fullText += story.Continue();
    }
    
    // 获取当前标签
    const tags = story.currentTags;
    const parsedTags = parseTags(tags);
    
    // 获取可用选择
    const choices = story.currentChoices.map((choice: any, index: number) => ({
      index,
      text: choice.text,
    }));
    
    // 获取所有变量状态
    const variables: Record<string, any> = {};
    for (const varName of story.variablesState.GetEnumerator()) {
      variables[varName] = story.variablesState.$(varName);
    }
    
    // 检查是否到达结局
    const isEnded = !story.canContinue && choices.length === 0;
    
    return new Response(
      JSON.stringify({
        text: fullText.trim(),
        choices,
        tags: parsedTags,
        variables,
        isEnded,
        canContinue: story.canContinue,
      }),
      {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      },
    );
  } catch (error) {
    console.error("ink-runtime error:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      },
    );
  }
});
