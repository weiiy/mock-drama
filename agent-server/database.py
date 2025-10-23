"""
数据库管理器
处理所有数据库操作
"""

from supabase import create_client, Client
from typing import Dict, Any, List, Optional
import uuid
from datetime import datetime

class DatabaseManager:
    """数据库管理器"""
    
    def __init__(self, supabase_url: str, supabase_key: str):
        self.client: Client = create_client(supabase_url, supabase_key)
    
    def create_session(
        self,
        user_id: str,
        story_id: str
    ) -> Dict[str, Any]:
        """创建新游戏会话"""
        session_id = str(uuid.uuid4())
        
        # 创建会话
        session_data = {
            "id": session_id,
            "user_id": user_id,
            "story_id": story_id,
            "current_chapter": 1,
            "current_situation": self._get_initial_situation(story_id),
            "is_completed": False
        }
        
        result = self.client.table("game_sessions").insert(session_data).execute()
        
        # 初始化局势状态
        self._initialize_situations(session_id, story_id)
        
        # 初始化角色状态
        self._initialize_characters(session_id, story_id)
        
        return result.data[0]
    
    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """获取会话信息"""
        result = self.client.table("game_sessions")\
            .select("*")\
            .eq("id", session_id)\
            .single()\
            .execute()
        
        return result.data if result.data else None
    
    def update_session(
        self,
        session_id: str,
        updates: Dict[str, Any]
    ):
        """更新会话"""
        self.client.table("game_sessions")\
            .update(updates)\
            .eq("id", session_id)\
            .execute()
    
    def save_message(
        self,
        session_id: str,
        role: str,
        content: str
    ):
        """保存消息"""
        # 获取当前章节
        session = self.get_session(session_id)
        chapter = session["current_chapter"] if session else 1
        
        self.client.table("chat_messages").insert({
            "session_id": session_id,
            "chapter": chapter,
            "role": role,
            "content": content
        }).execute()
    
    def get_messages(
        self,
        session_id: str,
        limit: int = 20
    ) -> List[Dict[str, Any]]:
        """获取消息历史"""
        result = self.client.table("chat_messages")\
            .select("*")\
            .eq("session_id", session_id)\
            .order("created_at", desc=True)\
            .limit(limit)\
            .execute()
        
        # 反转顺序（最早的在前）
        return list(reversed(result.data))
    
    def update_situation(
        self,
        session_id: str,
        situation_id: str,
        updates: Dict[str, Any]
    ):
        """更新局势状态"""
        self.client.table("situation_states")\
            .update(updates)\
            .eq("session_id", session_id)\
            .eq("situation_id", situation_id)\
            .execute()
    
    def get_situations(
        self,
        session_id: str,
        chapter: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """获取局势状态"""
        query = self.client.table("situation_states")\
            .select("*")\
            .eq("session_id", session_id)
        
        if chapter is not None:
            query = query.eq("chapter", chapter)
        
        result = query.execute()
        return result.data
    
    def update_character(
        self,
        session_id: str,
        character_name: str,
        updates: Dict[str, Any]
    ):
        """更新角色状态"""
        self.client.table("character_states")\
            .update(updates)\
            .eq("session_id", session_id)\
            .eq("character_name", character_name)\
            .execute()
    
    def get_characters(
        self,
        session_id: str
    ) -> List[Dict[str, Any]]:
        """获取所有角色状态"""
        result = self.client.table("character_states")\
            .select("*")\
            .eq("session_id", session_id)\
            .execute()
        
        return result.data
    
    def save_ending(
        self,
        session_id: str,
        ending_type: str,
        ending_content: str,
        situations_completed: Dict[str, List[str]]
    ):
        """保存结局"""
        self.client.table("endings").insert({
            "session_id": session_id,
            "ending_type": ending_type,
            "ending_content": ending_content,
            "situations_completed": situations_completed
        }).execute()
        
        # 标记会话为已完成
        self.update_session(session_id, {
            "is_completed": True,
            "ending_type": ending_type
        })
    
    def health_check(self):
        """健康检查"""
        # 简单查询测试连接
        self.client.table("game_sessions").select("id").limit(1).execute()
    
    # ============ 私有方法 ============
    
    def _get_initial_situation(self, story_id: str) -> str:
        """获取初始局势"""
        # 根据剧本返回第一个局势
        initial_situations = {
            "chongzhen": "eunuch_party",
            # 其他剧本...
        }
        return initial_situations.get(story_id, "initial")
    
    def _initialize_situations(self, session_id: str, story_id: str):
        """初始化局势状态"""
        # 根据剧本配置初始化局势
        if story_id == "chongzhen":
            situations = [
                {
                    "session_id": session_id,
                    "chapter": 1,
                    "situation_id": "eunuch_party",
                    "situation_type": "main",
                    "score": 0,
                    "target_score": 100,
                    "status": "in_progress"
                },
                {
                    "session_id": session_id,
                    "chapter": 1,
                    "situation_id": "border_defense",
                    "situation_type": "optional",
                    "score": 0,
                    "target_score": 80,
                    "status": "in_progress"
                }
            ]
            
            self.client.table("situation_states").insert(situations).execute()
    
    def _initialize_characters(self, session_id: str, story_id: str):
        """初始化角色状态"""
        # 根据剧本配置初始化角色
        if story_id == "chongzhen":
            characters = [
                {
                    "session_id": session_id,
                    "character_name": "崇祯皇帝",
                    "status": "alive",
                    "attributes": {
                        "authority": 70,
                        "wisdom": 60
                    }
                },
                {
                    "session_id": session_id,
                    "character_name": "袁崇焕",
                    "status": "alive",
                    "attributes": {
                        "loyalty": 95,
                        "military_ability": 90
                    }
                },
                {
                    "session_id": session_id,
                    "character_name": "李自成",
                    "status": "alive",
                    "attributes": {
                        "power": 30,
                        "army_size": 10000
                    }
                }
            ]
            
            self.client.table("character_states").insert(characters).execute()
