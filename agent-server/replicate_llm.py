"""
Replicate API LLM 包装器
用于 CrewAI Agent
"""

import os
import requests
import time
from typing import List, Dict, Any, Optional
from langchain_core.language_models.llms import LLM
from langchain_core.callbacks.manager import CallbackManagerForLLMRun


class ReplicateLLM(LLM):
    """Replicate API LLM 包装器"""
    
    model: str = "openai/gpt-5-mini"
    replicate_api_token: str = ""
    max_tokens: int = 1024
    temperature: float = 0.7
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if not self.replicate_api_token:
            self.replicate_api_token = os.getenv("REPLICATE_API_TOKEN", "")
    
    @property
    def _llm_type(self) -> str:
        return "replicate"
    
    def _call(
        self,
        prompt: str,
        stop: Optional[List[str]] = None,
        run_manager: Optional[CallbackManagerForLLMRun] = None,
        **kwargs: Any,
    ) -> str:
        """调用 Replicate API"""
        
        if not self.replicate_api_token:
            raise ValueError("REPLICATE_API_TOKEN 未设置")
        
        # 创建预测
        prediction_url = f"https://api.replicate.com/v1/models/{self.model}/predictions"
        
        headers = {
            "Authorization": f"Bearer {self.replicate_api_token}",
            "Content-Type": "application/json",
        }
        
        payload = {
            "input": {
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "max_output_tokens": self.max_tokens,
                "temperature": self.temperature,
            }
        }
        
        # 创建预测
        response = requests.post(prediction_url, json=payload, headers=headers)
        
        if response.status_code != 201:
            error_detail = response.text
            raise Exception(f"Replicate API 错误: {response.status_code} - {error_detail}")
        
        prediction = response.json()
        prediction_id = prediction["id"]
        get_url = prediction["urls"]["get"]
        
        # 轮询结果
        max_attempts = 60  # 最多等待 60 秒
        for _ in range(max_attempts):
            time.sleep(1)
            
            result_response = requests.get(get_url, headers=headers)
            if result_response.status_code != 200:
                continue
            
            result = result_response.json()
            status = result.get("status")
            
            if status == "succeeded":
                output = result.get("output", "")
                if isinstance(output, list):
                    return "".join(output)
                return str(output)
            
            elif status == "failed":
                error = result.get("error", "未知错误")
                raise Exception(f"Replicate 预测失败: {error}")
            
            elif status == "canceled":
                raise Exception("Replicate 预测被取消")
        
        raise Exception("Replicate 预测超时")
    
    @property
    def _identifying_params(self) -> Dict[str, Any]:
        """返回标识参数"""
        return {
            "model": self.model,
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
        }


def create_replicate_llm(
    model: str = "openai/gpt-5-mini",
    max_tokens: int = 1024,
    temperature: float = 0.7,
) -> ReplicateLLM:
    """创建 Replicate LLM 实例"""
    return ReplicateLLM(
        model=model,
        max_tokens=max_tokens,
        temperature=temperature,
    )
