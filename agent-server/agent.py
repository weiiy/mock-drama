"""
Story Agent 实现
处理 ink、记忆、LLM、判定逻辑
"""

import asyncio
from typing import Dict, Any, List
import httpx
import json

class StoryAgent:
    """
    故事 Agent - 协调所有组件
    """
    
    def __init__(self, session_id: str, story_id: str):
        self.session_id = session_id
        self.story_id = story_id
        self.http_client = httpx.AsyncClient(timeout=60.0)
        
    def get_ink_state(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """
        获取 ink 引擎状态
        """
        # 这里可以调用本地 ink 引擎或远程服务
        # 简化示例：直接返回模拟数据
        return {
            "current_text": "",
            "choices": [],
            "tags": {
                "chapter": state.get("current_chapter", 1),
                "situation": state.get("current_situation", "initial")
            },
            "variables": state.get("state_variables", {})
        }
    
    def retrieve_memories(
        self,
        state: Dict[str, Any],
        query: str
    ) -> List[Dict[str, Any]]:
        """
        从向量数据库检索相关记忆
        """
        # 调用 Supabase 或独立向量数据库
        # 简化示例
        return []
    
    async def generate_story(
        self,
        state: Dict[str, Any],
        ink_state: Dict[str, Any],
        memories: List[Dict[str, Any]],
        user_input: str
    ) -> str:
        """
        调用 LLM 生成剧情
        """
        # 构建系统提示词
        system_prompt = self._build_system_prompt(state, ink_state, memories)
        
        # 调用 Replicate API
        response = await self.http_client.post(
            "https://api.replicate.com/v1/models/openai/gpt-5-mini/predictions",
            headers={
                "Authorization": f"Bearer {self._get_replicate_token()}",
                "Content-Type": "application/json"
            },
            json={
                "input": {
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_input}
                    ],
                    "max_output_tokens": 1024
                }
            }
        )
        
        prediction = response.json()
        
        # 轮询结果
        while prediction["status"] not in ["succeeded", "failed"]:
            await asyncio.sleep(1)
            response = await self.http_client.get(
                prediction["urls"]["get"],
                headers={"Authorization": f"Bearer {self._get_replicate_token()}"}
            )
            prediction = response.json()
        
        if prediction["status"] == "succeeded":
            return prediction["output"]
        else:
            raise Exception(f"LLM generation failed: {prediction.get('error')}")
    
    async def evaluate_situation(
        self,
        state: Dict[str, Any],
        ink_state: Dict[str, Any],
        llm_response: str
    ) -> Dict[str, Any]:
        """
        判定器：评估是否推进剧情
        """
        judgment_prompt = f"""
根据以下信息判断剧情进展：

当前章节：{state.get('current_chapter', 1)}
当前局势：{state.get('current_situation', 'initial')}
状态变量：{json.dumps(state.get('state_variables', {}), ensure_ascii=False)}
最新剧情：{llm_response}

请判断：
1. 当前局势完成度（0-100分）
2. 是否应该进入下一章节
3. 是否应该结束故事

返回 JSON 格式：
{{
  "situationScore": 85,
  "shouldAdvanceChapter": true,
  "shouldEndStory": false,
  "rationale": "判断理由",
  "stateChanges": {{
    "variable_name": new_value
  }}
}}
"""
        
        # 调用 LLM 进行判定
        response = await self.http_client.post(
            "https://api.replicate.com/v1/models/openai/gpt-5-mini/predictions",
            headers={
                "Authorization": f"Bearer {self._get_replicate_token()}",
                "Content-Type": "application/json"
            },
            json={
                "input": {
                    "messages": [{"role": "user", "content": judgment_prompt}],
                    "max_output_tokens": 512
                }
            }
        )
        
        prediction = response.json()
        
        # 轮询结果
        while prediction["status"] not in ["succeeded", "failed"]:
            await asyncio.sleep(1)
            response = await self.http_client.get(
                prediction["urls"]["get"],
                headers={"Authorization": f"Bearer {self._get_replicate_token()}"}
            )
            prediction = response.json()
        
        if prediction["status"] == "succeeded":
            try:
                judgment = json.loads(prediction["output"])
                return {
                    "shouldContinue": judgment["situationScore"] < 100,
                    "shouldAdvanceChapter": judgment["shouldAdvanceChapter"],
                    "shouldEndStory": judgment["shouldEndStory"],
                    "situationUpdate": {
                        "situation": state.get("current_situation"),
                        "score": judgment["situationScore"],
                        "rationale": judgment["rationale"]
                    },
                    "stateChanges": judgment.get("stateChanges", {})
                }
            except json.JSONDecodeError:
                # 解析失败，使用默认判定
                return {
                    "shouldContinue": True,
                    "shouldAdvanceChapter": False,
                    "shouldEndStory": False
                }
        else:
            raise Exception(f"Judgment failed: {prediction.get('error')}")
    
    def update_state(
        self,
        state: Dict[str, Any],
        decision: Dict[str, Any],
        response: str
    ) -> Dict[str, Any]:
        """
        更新状态
        """
        updated_state = state.copy()
        
        # 更新状态变量
        if decision.get("stateChanges"):
            if "state_variables" not in updated_state:
                updated_state["state_variables"] = {}
            updated_state["state_variables"].update(decision["stateChanges"])
        
        # 推进章节
        if decision.get("shouldAdvanceChapter"):
            updated_state["current_chapter"] = state.get("current_chapter", 1) + 1
        
        # 更新局势
        if decision.get("situationUpdate"):
            updated_state["current_situation"] = decision["situationUpdate"]["situation"]
        
        return updated_state
    
    def _build_system_prompt(
        self,
        state: Dict[str, Any],
        ink_state: Dict[str, Any],
        memories: List[Dict[str, Any]]
    ) -> str:
        """
        构建系统提示词
        """
        memory_context = "\n".join([m.get("summary", "") for m in memories])
        
        return f"""你是{self.story_id}剧本的叙事者。

当前章节：第{state.get('current_chapter', 1)}章
当前局势：{state.get('current_situation', 'initial')}

状态变量：
{json.dumps(state.get('state_variables', {}), ensure_ascii=False, indent=2)}

历史记忆：
{memory_context}

请根据玩家的选择，生成生动的剧情描述。注意：
1. 保持角色一致性
2. 根据状态变量调整剧情
3. 为玩家提供有意义的选择
4. 推动剧情向前发展"""
    
    def _get_replicate_token(self) -> str:
        """
        获取 Replicate API Token
        """
        import os
        return os.getenv("REPLICATE_API_TOKEN", "")
