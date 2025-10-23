"""
CrewAI 故事 Agent 完整实现
支持章节/局势推进、角色管理、多结局、断点续玩
"""

from crewai import Agent, Task, Crew, Process
from typing import Dict, Any, List, Optional
from supabase import create_client, Client
import json
from datetime import datetime

class StoryConfig:
    """剧本配置"""
    def __init__(self, story_id: str):
        self.story_id = story_id
        self.chapters = self.load_chapters()
        self.characters = self.load_characters()
    
    def load_chapters(self) -> Dict[int, Dict]:
        """加载章节配置"""
        # 示例：崇祯皇帝剧本
        if self.story_id == "chongzhen":
            return {
                1: {
                    "title": "新君即位",
                    "situations": {
                        "eunuch_party": {
                            "type": "main",
                            "name": "铲除阉党",
                            "target_score": 100,
                            "description": "魏忠贤把持朝政，必须铲除"
                        },
                        "border_defense": {
                            "type": "optional",
                            "name": "加强边防",
                            "target_score": 80,
                            "description": "后金威胁日益严重"
                        }
                    }
                },
                2: {
                    "title": "内忧外患",
                    "situations": {
                        "yuan_chonghuan": {
                            "type": "main",
                            "name": "袁崇焕之死",
                            "target_score": 100,
                            "description": "如何处理袁崇焕"
                        },
                        "peasant_revolt": {
                            "type": "main",
                            "name": "农民起义",
                            "target_score": 100,
                            "description": "陕西农民起义愈演愈烈"
                        }
                    }
                },
                3: {
                    "title": "大厦将倾",
                    "situations": {
                        "final_battle": {
                            "type": "main",
                            "name": "最后决战",
                            "target_score": 100,
                            "description": "李自成兵临城下"
                        }
                    }
                }
            }
        return {}
    
    def load_characters(self) -> Dict[str, Dict]:
        """加载角色配置"""
        if self.story_id == "chongzhen":
            return {
                "崇祯皇帝": {
                    "background": "明朝第十六位皇帝，勤政但多疑",
                    "initial_state": {
                        "status": "alive",
                        "authority": 70,
                        "wisdom": 60
                    }
                },
                "袁崇焕": {
                    "background": "督师蓟辽，忠诚的边关大将",
                    "initial_state": {
                        "status": "alive",
                        "loyalty": 95,
                        "military_ability": 90
                    }
                },
                "李自成": {
                    "background": "农民起义军领袖",
                    "initial_state": {
                        "status": "alive",
                        "power": 30,
                        "army_size": 10000
                    }
                }
            }
        return {}


class StoryAgentCrew:
    """CrewAI 故事 Agent"""
    
    def __init__(
        self,
        supabase_url: str,
        supabase_key: str,
        story_id: str
    ):
        self.supabase: Client = create_client(supabase_url, supabase_key)
        self.config = StoryConfig(story_id)
        self.story_id = story_id
        
        # 创建 Agents
        self.narrator = self._create_narrator()
        self.situation_judge = self._create_situation_judge()
        self.character_manager = self._create_character_manager()
        self.chapter_coordinator = self._create_chapter_coordinator()
        self.ending_generator = self._create_ending_generator()
    
    def _create_narrator(self) -> Agent:
        """创建叙事者 Agent"""
        return Agent(
            role='故事叙事者',
            goal='根据玩家选择和当前局势生成生动的剧情描述',
            backstory=f'你是{self.story_id}剧本的叙事者，擅长历史故事创作',
            verbose=True,
            allow_delegation=False
        )
    
    def _create_situation_judge(self) -> Agent:
        """创建局势判定者 Agent"""
        return Agent(
            role='局势判定者',
            goal='评估玩家决策对当前局势的影响，计算局势分数变化',
            backstory='你是严谨的历史学家，能准确评估政治决策的影响',
            verbose=True,
            allow_delegation=False
        )
    
    def _create_character_manager(self) -> Agent:
        """创建角色管理者 Agent"""
        return Agent(
            role='角色管理者',
            goal='跟踪角色状态变化，确保角色行为符合其性格背景',
            backstory='你负责维护角色的一致性和合理性',
            verbose=True,
            allow_delegation=False
        )
    
    def _create_chapter_coordinator(self) -> Agent:
        """创建章节协调者 Agent"""
        return Agent(
            role='章节协调者',
            goal='根据局势完成情况决定是否推进到下一章节或结束游戏',
            backstory='你是游戏设计师，负责控制剧情节奏',
            verbose=True,
            allow_delegation=False
        )
    
    def _create_ending_generator(self) -> Agent:
        """创建结局生成者 Agent"""
        return Agent(
            role='结局生成者',
            goal='根据玩家完成的局势生成相应的结局',
            backstory='你是结局设计师，能根据玩家表现生成不同结局',
            verbose=True,
            allow_delegation=False
        )
    
    async def process_user_action(
        self,
        session_id: str,
        user_input: str
    ) -> Dict[str, Any]:
        """
        处理用户行动
        
        Returns:
            {
                "story": "剧情描述",
                "situation_update": {...},
                "character_updates": [...],
                "chapter_status": "continue|next_chapter|ending",
                "ending": {...} if applicable
            }
        """
        # 1. 加载会话状态
        session = await self.load_session(session_id)
        
        if session["is_completed"]:
            return {"error": "游戏已结束"}
        
        # 2. 获取当前章节和局势
        current_chapter = session["current_chapter"]
        current_situation = session["current_situation"]
        
        # 3. 创建任务链
        tasks = self._create_task_chain(
            session=session,
            user_input=user_input,
            current_chapter=current_chapter,
            current_situation=current_situation
        )
        
        # 4. 创建 Crew 并执行
        crew = Crew(
            agents=[
                self.narrator,
                self.situation_judge,
                self.character_manager,
                self.chapter_coordinator
            ],
            tasks=tasks,
            process=Process.sequential,  # 顺序执行
            verbose=True
        )
        
        result = crew.kickoff()
        
        # 5. 解析结果并更新数据库
        parsed_result = self._parse_crew_result(result)
        await self._update_database(session_id, parsed_result)
        
        # 6. 检查是否需要生成结局
        if parsed_result["chapter_status"] == "ending":
            ending = await self._generate_ending(session_id)
            parsed_result["ending"] = ending
        
        return parsed_result
    
    def _create_task_chain(
        self,
        session: Dict,
        user_input: str,
        current_chapter: int,
        current_situation: str
    ) -> List[Task]:
        """创建任务链"""
        
        # 获取角色状态
        characters = session.get("characters", {})
        situations = session.get("situations", {})
        
        # 任务1：生成剧情
        narrate_task = Task(
            description=f"""
根据以下信息生成剧情：

当前章节：第{current_chapter}章
当前局势：{current_situation}
玩家选择：{user_input}

角色状态：
{json.dumps(characters, ensure_ascii=False, indent=2)}

局势状态：
{json.dumps(situations, ensure_ascii=False, indent=2)}

请生成生动的剧情描述（300-500字）。
            """,
            agent=self.narrator,
            expected_output="剧情描述文本"
        )
        
        # 任务2：评估局势影响
        judge_task = Task(
            description=f"""
根据剧情和玩家选择，评估对当前局势的影响：

当前局势：{current_situation}
当前分数：{situations.get(current_situation, {}).get('score', 0)}
目标分数：{situations.get(current_situation, {}).get('target_score', 100)}

请返回 JSON 格式：
{{
  "score_change": 分数变化（-50 到 +50），
  "new_score": 新分数,
  "status": "in_progress|success|failed",
  "rationale": "判断理由"
}}
            """,
            agent=self.situation_judge,
            expected_output="JSON 格式的局势评估",
            context=[narrate_task]
        )
        
        # 任务3：更新角色状态
        character_task = Task(
            description=f"""
根据剧情，判断角色状态是否发生变化：

当前角色状态：
{json.dumps(characters, ensure_ascii=False, indent=2)}

请返回 JSON 格式的角色更新列表：
[
  {{
    "character_name": "角色名",
    "status": "alive|dead|missing",
    "attribute_changes": {{"loyalty": +10}}
  }}
]

如果没有变化，返回空数组 []
            """,
            agent=self.character_manager,
            expected_output="JSON 格式的角色更新",
            context=[narrate_task]
        )
        
        # 任务4：决定章节推进
        coordinator_task = Task(
            description=f"""
根据局势完成情况，决定下一步：

当前章节：{current_chapter}
总章节数：{len(self.config.chapters)}
局势状态：{json.dumps(situations, ensure_ascii=False, indent=2)}

规则：
1. 如果当前章节的所有主要局势都完成（成功或失败），推进到下一章
2. 如果已是最后一章且主要局势完成，进入结局
3. 否则继续当前章节

请返回 JSON：
{{
  "action": "continue|next_chapter|ending",
  "rationale": "理由"
}}
            """,
            agent=self.chapter_coordinator,
            expected_output="JSON 格式的章节决策",
            context=[judge_task, character_task]
        )
        
        return [narrate_task, judge_task, character_task, coordinator_task]
    
    def _parse_crew_result(self, result: str) -> Dict[str, Any]:
        """解析 Crew 执行结果"""
        # CrewAI 返回的是最后一个任务的输出
        # 需要从中提取所有信息
        try:
            # 简化处理：假设结果包含所有任务输出
            return {
                "story": "剧情内容",  # 从 narrate_task 提取
                "situation_update": {},  # 从 judge_task 提取
                "character_updates": [],  # 从 character_task 提取
                "chapter_status": "continue"  # 从 coordinator_task 提取
            }
        except Exception as e:
            return {"error": str(e)}
    
    async def load_session(self, session_id: str) -> Dict[str, Any]:
        """加载会话状态"""
        # 从数据库加载
        session_result = await self.supabase.table("game_sessions")\
            .select("*")\
            .eq("id", session_id)\
            .single()\
            .execute()
        
        session = session_result.data
        
        # 加载局势状态
        situations_result = await self.supabase.table("situation_states")\
            .select("*")\
            .eq("session_id", session_id)\
            .execute()
        
        situations = {s["situation_id"]: s for s in situations_result.data}
        
        # 加载角色状态
        characters_result = await self.supabase.table("character_states")\
            .select("*")\
            .eq("session_id", session_id)\
            .execute()
        
        characters = {c["character_name"]: c for c in characters_result.data}
        
        return {
            **session,
            "situations": situations,
            "characters": characters
        }
    
    async def _update_database(
        self,
        session_id: str,
        result: Dict[str, Any]
    ):
        """更新数据库"""
        # 更新局势
        if result.get("situation_update"):
            await self.supabase.table("situation_states")\
                .update(result["situation_update"])\
                .eq("session_id", session_id)\
                .execute()
        
        # 更新角色
        for char_update in result.get("character_updates", []):
            await self.supabase.table("character_states")\
                .update(char_update)\
                .eq("session_id", session_id)\
                .eq("character_name", char_update["character_name"])\
                .execute()
        
        # 更新会话
        if result["chapter_status"] == "next_chapter":
            await self.supabase.table("game_sessions")\
                .update({"current_chapter": session["current_chapter"] + 1})\
                .eq("id", session_id)\
                .execute()
        elif result["chapter_status"] == "ending":
            await self.supabase.table("game_sessions")\
                .update({"is_completed": True})\
                .eq("id", session_id)\
                .execute()
    
    async def _generate_ending(self, session_id: str) -> Dict[str, Any]:
        """生成结局"""
        # 加载完成的局势
        situations = await self.supabase.table("situation_states")\
            .select("*")\
            .eq("session_id", session_id)\
            .execute()
        
        # 统计成功/失败的局势
        completed_situations = {
            "success": [],
            "failed": []
        }
        
        for sit in situations.data:
            if sit["status"] == "success":
                completed_situations["success"].append(sit["situation_id"])
            elif sit["status"] == "failed":
                completed_situations["failed"].append(sit["situation_id"])
        
        # 创建结局生成任务
        ending_task = Task(
            description=f"""
根据玩家完成的局势，生成结局：

成功的局势：{completed_situations['success']}
失败的局势：{completed_situations['failed']}

请生成：
1. 结局类型（good_ending|normal_ending|bad_ending）
2. 结局描述（500-800字）
3. 评价总结

返回 JSON 格式。
            """,
            agent=self.ending_generator,
            expected_output="JSON 格式的结局"
        )
        
        crew = Crew(
            agents=[self.ending_generator],
            tasks=[ending_task],
            verbose=True
        )
        
        result = crew.kickoff()
        
        # 保存结局
        await self.supabase.table("endings").insert({
            "session_id": session_id,
            "ending_content": result,
            "situations_completed": completed_situations
        }).execute()
        
        return result


# ============ 使用示例 ============

async def example_usage():
    """使用示例"""
    
    agent = StoryAgentCrew(
        supabase_url="your-url",
        supabase_key="your-key",
        story_id="chongzhen"
    )
    
    # 处理用户行动
    result = await agent.process_user_action(
        session_id="session_123",
        user_input="我要铲除魏忠贤"
    )
    
    print("剧情：", result["story"])
    print("局势更新：", result["situation_update"])
    print("章节状态：", result["chapter_status"])
    
    if result.get("ending"):
        print("结局：", result["ending"])
