"""
角色知识库系统
用于存储和检索角色背景、状态、关系等信息
"""

from typing import List, Dict, Any, Optional
from supabase import create_client, Client
from sentence_transformers import SentenceTransformer
import numpy as np
import json

class CharacterKnowledgeBase:
    """
    角色知识库
    支持向量检索和结构化查询
    """
    
    def __init__(self, supabase_url: str, supabase_key: str):
        self.supabase: Client = create_client(supabase_url, supabase_key)
        
        # 使用本地嵌入模型（免费）
        self.embedding_model = SentenceTransformer(
            'paraphrase-multilingual-MiniLM-L12-v2'
        )
        
        # 或者使用 OpenAI（更好但收费）
        # import openai
        # self.openai_client = openai.OpenAI()
    
    def generate_embedding(self, text: str) -> List[float]:
        """
        生成文本嵌入
        """
        # 方式1：本地模型（免费）
        embedding = self.embedding_model.encode(text)
        return embedding.tolist()
        
        # 方式2：OpenAI（更好但收费）
        # response = self.openai_client.embeddings.create(
        #     model="text-embedding-3-small",
        #     input=text
        # )
        # return response.data[0].embedding
    
    async def add_character(
        self,
        story_id: str,
        character_name: str,
        background: str,
        personality: str,
        relationships: Dict[str, str],
        initial_state: Dict[str, Any],
        metadata: Optional[Dict[str, Any]] = None
    ):
        """
        添加角色到知识库
        
        Args:
            story_id: 剧本 ID
            character_name: 角色名称
            background: 背景故事
            personality: 性格特点
            relationships: 与其他角色的关系
            initial_state: 初始状态（如职位、能力值等）
            metadata: 额外元数据
        """
        # 合并所有文本用于生成嵌入
        full_text = f"""
角色：{character_name}

背景：
{background}

性格：
{personality}

关系：
{json.dumps(relationships, ensure_ascii=False, indent=2)}

初始状态：
{json.dumps(initial_state, ensure_ascii=False, indent=2)}
"""
        
        # 生成嵌入
        embedding = self.generate_embedding(full_text)
        
        # 存储到数据库
        await self.supabase.table("character_knowledge").insert({
            "story_id": story_id,
            "character_name": character_name,
            "background": background,
            "personality": personality,
            "relationships": relationships,
            "current_state": initial_state,
            "embedding": embedding,
            "metadata": metadata or {},
            "content_type": "character_profile"
        }).execute()
    
    async def add_character_memory(
        self,
        story_id: str,
        character_name: str,
        event: str,
        chapter: int,
        importance: float = 0.5
    ):
        """
        添加角色记忆（发生的事件）
        
        Args:
            story_id: 剧本 ID
            character_name: 角色名称
            event: 事件描述
            chapter: 发生的章节
            importance: 重要性（0-1）
        """
        embedding = self.generate_embedding(event)
        
        await self.supabase.table("character_knowledge").insert({
            "story_id": story_id,
            "character_name": character_name,
            "content": event,
            "embedding": embedding,
            "metadata": {
                "chapter": chapter,
                "importance": importance,
                "type": "memory"
            },
            "content_type": "character_memory"
        }).execute()
    
    async def update_character_state(
        self,
        story_id: str,
        character_name: str,
        state_updates: Dict[str, Any]
    ):
        """
        更新角色状态
        
        Args:
            story_id: 剧本 ID
            character_name: 角色名称
            state_updates: 状态更新（如 {"loyalty": 80, "power": 50}）
        """
        # 获取当前角色
        result = await self.supabase.table("character_knowledge")\
            .select("*")\
            .eq("story_id", story_id)\
            .eq("character_name", character_name)\
            .eq("content_type", "character_profile")\
            .execute()
        
        if result.data:
            character = result.data[0]
            current_state = character.get("current_state", {})
            
            # 合并状态
            new_state = {**current_state, **state_updates}
            
            # 更新数据库
            await self.supabase.table("character_knowledge")\
                .update({"current_state": new_state})\
                .eq("id", character["id"])\
                .execute()
    
    async def retrieve_character_info(
        self,
        story_id: str,
        query: str,
        limit: int = 5,
        threshold: float = 0.7
    ) -> List[Dict[str, Any]]:
        """
        检索相关的角色信息
        
        Args:
            story_id: 剧本 ID
            query: 查询文本（如"忠诚的大臣"）
            limit: 返回数量
            threshold: 相似度阈值
        
        Returns:
            相关角色信息列表
        """
        # 生成查询嵌入
        query_embedding = self.generate_embedding(query)
        
        # 调用 Supabase RPC 函数进行向量搜索
        result = await self.supabase.rpc(
            "match_character_knowledge",
            {
                "query_embedding": query_embedding,
                "match_threshold": threshold,
                "match_count": limit,
                "story_filter": story_id
            }
        ).execute()
        
        return result.data
    
    async def get_character_by_name(
        self,
        story_id: str,
        character_name: str
    ) -> Optional[Dict[str, Any]]:
        """
        根据名称获取角色完整信息
        """
        result = await self.supabase.table("character_knowledge")\
            .select("*")\
            .eq("story_id", story_id)\
            .eq("character_name", character_name)\
            .eq("content_type", "character_profile")\
            .execute()
        
        if result.data:
            return result.data[0]
        return None
    
    async def get_character_memories(
        self,
        story_id: str,
        character_name: str,
        chapter: Optional[int] = None,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """
        获取角色的记忆（发生过的事件）
        """
        query = self.supabase.table("character_knowledge")\
            .select("*")\
            .eq("story_id", story_id)\
            .eq("character_name", character_name)\
            .eq("content_type", "character_memory")\
            .order("created_at", desc=True)\
            .limit(limit)
        
        if chapter is not None:
            query = query.eq("metadata->>chapter", chapter)
        
        result = await query.execute()
        return result.data
    
    async def get_all_characters(
        self,
        story_id: str
    ) -> List[Dict[str, Any]]:
        """
        获取剧本的所有角色
        """
        result = await self.supabase.table("character_knowledge")\
            .select("*")\
            .eq("story_id", story_id)\
            .eq("content_type", "character_profile")\
            .execute()
        
        return result.data


# ============ 使用示例 ============

async def example_usage():
    """示例：崇祯皇帝剧本的角色知识库"""
    
    kb = CharacterKnowledgeBase(
        supabase_url="your-supabase-url",
        supabase_key="your-supabase-key"
    )
    
    # 1. 添加崇祯皇帝
    await kb.add_character(
        story_id="chongzhen",
        character_name="崇祯皇帝",
        background="""
朱由检，明朝第十六位皇帝，年号崇祯。
天启七年（1627年）即位，时年十七岁。
即位之初，面临内忧外患：
- 内有阉党专权、东林党争
- 外有后金（清）威胁、农民起义
- 国库空虚、民不聊生
        """,
        personality="""
- 勤政：每日批阅奏折至深夜
- 多疑：频繁更换大臣，难以信任他人
- 刚愎：不愿承认错误，固执己见
- 节俭：生活简朴，不好奢华
        """,
        relationships={
            "袁崇焕": "边关大将，曾寄予厚望，后因多疑将其处死",
            "温体仁": "内阁首辅，善于揣摩圣意",
            "周延儒": "内阁大学士，反复起用",
            "李自成": "农民起义军首领，最终攻破北京"
        },
        initial_state={
            "age": 17,
            "reign_year": 1,
            "treasury": 100,  # 库银（万两）
            "army_morale": 50,  # 军队士气
            "people_loyalty": 60,  # 民心
            "emperor_authority": 70,  # 皇权
            "corruption_level": 80  # 腐败程度
        },
        metadata={
            "importance": "protagonist",
            "role": "emperor"
        }
    )
    
    # 2. 添加袁崇焕
    await kb.add_character(
        story_id="chongzhen",
        character_name="袁崇焕",
        background="""
明朝末年著名军事将领，督师蓟辽。
曾在宁远、宁锦之战中击败后金军队。
提出"五年复辽"的战略计划。
        """,
        personality="""
- 忠诚：一心为国，誓死守卫边疆
- 果断：军事决策果断，善于用兵
- 直言：敢于直谏，不畏权贵
        """,
        relationships={
            "崇祯皇帝": "君臣关系，深受信任但最终被冤杀",
            "皇太极": "敌对关系，多次交战"
        },
        initial_state={
            "position": "督师蓟辽",
            "loyalty": 95,
            "military_ability": 90,
            "political_skill": 60
        }
    )
    
    # 3. 添加李自成
    await kb.add_character(
        story_id="chongzhen",
        character_name="李自成",
        background="""
明末农民起义军领袖，建立大顺政权。
原为驿卒，因朝廷裁撤驿站而失业。
聚众起义，提出"均田免赋"口号。
        """,
        personality="""
- 坚韧：屡败屡战，不屈不挠
- 野心：志在推翻明朝，建立新朝
- 残暴：攻城后常屠城掠夺
        """,
        relationships={
            "崇祯皇帝": "敌对关系，最终攻破北京",
            "吴三桂": "曾试图招降，后反目成仇"
        },
        initial_state={
            "power": 30,  # 势力
            "army_size": 10000,
            "territory": ["陕西部分地区"]
        }
    )
    
    # 4. 记录事件
    await kb.add_character_memory(
        story_id="chongzhen",
        character_name="崇祯皇帝",
        event="崇祯元年，下令铲除阉党，魏忠贤自缢身亡",
        chapter=1,
        importance=0.9
    )
    
    await kb.add_character_memory(
        story_id="chongzhen",
        character_name="袁崇焕",
        event="崇祯二年，袁崇焕因反间计被崇祯皇帝下令凌迟处死",
        chapter=2,
        importance=1.0
    )
    
    # 5. 更新角色状态
    await kb.update_character_state(
        story_id="chongzhen",
        character_name="崇祯皇帝",
        state_updates={
            "reign_year": 2,
            "treasury": 80,  # 库银减少
            "emperor_authority": 75  # 铲除阉党后皇权增强
        }
    )
    
    # 6. 检索相关角色
    results = await kb.retrieve_character_info(
        story_id="chongzhen",
        query="忠诚的武将",
        limit=3
    )
    print("相关角色：", results)
    
    # 7. 获取特定角色
    yuan = await kb.get_character_by_name(
        story_id="chongzhen",
        character_name="袁崇焕"
    )
    print("袁崇焕信息：", yuan)
    
    # 8. 获取角色记忆
    memories = await kb.get_character_memories(
        story_id="chongzhen",
        character_name="崇祯皇帝",
        chapter=1
    )
    print("第一章事件：", memories)


# ============ 在 Agent 中使用 ============

class StoryAgentWithKnowledge:
    """
    集成角色知识库的 Agent
    """
    
    def __init__(self, knowledge_base: CharacterKnowledgeBase):
        self.kb = knowledge_base
    
    async def generate_story_with_context(
        self,
        story_id: str,
        user_input: str,
        current_state: Dict[str, Any]
    ):
        """
        生成剧情时自动检索相关角色信息
        """
        # 1. 从用户输入中提取提到的角色
        mentioned_characters = self.extract_characters(user_input)
        
        # 2. 获取这些角色的详细信息
        character_contexts = []
        for char_name in mentioned_characters:
            char_info = await self.kb.get_character_by_name(
                story_id=story_id,
                character_name=char_name
            )
            if char_info:
                character_contexts.append(char_info)
        
        # 3. 检索相关的历史事件
        relevant_memories = await self.kb.retrieve_character_info(
            story_id=story_id,
            query=user_input,
            limit=5
        )
        
        # 4. 构建增强的提示词
        enhanced_prompt = self.build_prompt_with_knowledge(
            user_input=user_input,
            current_state=current_state,
            character_contexts=character_contexts,
            relevant_memories=relevant_memories
        )
        
        # 5. 调用 LLM 生成剧情
        story = await self.call_llm(enhanced_prompt)
        
        # 6. 记录新事件到角色记忆
        await self.record_event(
            story_id=story_id,
            event=story,
            chapter=current_state["chapter"]
        )
        
        return story
    
    def build_prompt_with_knowledge(
        self,
        user_input: str,
        current_state: Dict[str, Any],
        character_contexts: List[Dict],
        relevant_memories: List[Dict]
    ) -> str:
        """
        构建包含角色知识的提示词
        """
        prompt = f"""
你是崇祯皇帝剧本的叙事者。

当前状态：
- 章节：第{current_state['chapter']}章
- 库银：{current_state.get('treasury', 0)}万两
- 军队士气：{current_state.get('army_morale', 0)}
- 民心：{current_state.get('people_loyalty', 0)}

相关角色信息：
"""
        
        for char in character_contexts:
            prompt += f"""
【{char['character_name']}】
背景：{char['background']}
性格：{char['personality']}
当前状态：{json.dumps(char['current_state'], ensure_ascii=False)}
"""
        
        prompt += "\n相关历史事件：\n"
        for memory in relevant_memories:
            prompt += f"- {memory.get('content', '')}\n"
        
        prompt += f"\n玩家选择：{user_input}\n"
        prompt += "\n请根据以上信息，生成生动的剧情描述。注意保持角色性格一致，考虑历史事件的影响。"
        
        return prompt
    
    def extract_characters(self, text: str) -> List[str]:
        """
        从文本中提取提到的角色名称
        """
        # 简单实现：匹配已知角色名
        known_characters = ["崇祯皇帝", "袁崇焕", "李自成", "温体仁", "周延儒"]
        mentioned = []
        for char in known_characters:
            if char in text:
                mentioned.append(char)
        return mentioned
    
    async def record_event(
        self,
        story_id: str,
        event: str,
        chapter: int
    ):
        """
        记录事件到相关角色的记忆
        """
        # 提取涉及的角色
        characters = self.extract_characters(event)
        
        # 为每个角色添加记忆
        for char_name in characters:
            await self.kb.add_character_memory(
                story_id=story_id,
                character_name=char_name,
                event=event,
                chapter=chapter,
                importance=0.7
            )


if __name__ == "__main__":
    import asyncio
    asyncio.run(example_usage())
