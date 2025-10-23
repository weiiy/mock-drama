"""
CrewAI Agent 服务器 - FastAPI 实现
支持章节/局势推进、角色管理、多结局、断点续玩
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import os
from dotenv import load_dotenv
import redis.asyncio as redis

# 导入 CrewAI Agent
from crewai_story_agent import StoryAgentCrew
from database import DatabaseManager

# 加载环境变量
load_dotenv()

app = FastAPI(
    title="Mock Drama Agent Server",
    description="CrewAI 驱动的互动剧本服务器",
    version="2.0.0"
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Redis 配置
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

# 全局变量
redis_client = None
db_manager = None
agent_crews = {}  # 缓存不同剧本的 Agent Crew

@app.on_event("startup")
async def startup():
    """启动时初始化"""
    global redis_client, db_manager
    
    # 初始化 Redis
    redis_client = await redis.from_url(REDIS_URL)
    
    # 初始化数据库管理器
    db_manager = DatabaseManager(
        supabase_url=os.getenv("SUPABASE_URL"),
        supabase_key=os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    )
    
    print("✅ 服务器启动成功")

@app.on_event("shutdown")
async def shutdown():
    """关闭时清理"""
    if redis_client:
        await redis_client.close()
    print("👋 服务器已关闭")

# ============ 数据模型 ============

class CreateSessionRequest(BaseModel):
    user_id: str
    story_id: str

class SessionResponse(BaseModel):
    session_id: str
    story_id: str
    current_chapter: int
    current_situation: str
    message: str

class ActionRequest(BaseModel):
    session_id: str
    user_input: str

class ActionResponse(BaseModel):
    story: str
    situation_update: Optional[Dict[str, Any]] = None
    character_updates: Optional[List[Dict[str, Any]]] = None
    chapter_status: str  # continue, next_chapter, ending
    ending: Optional[Dict[str, Any]] = None

# ============ 辅助函数 ============

def get_agent_crew(story_id: str) -> StoryAgentCrew:
    """获取或创建 Agent Crew"""
    if story_id not in agent_crews:
        agent_crews[story_id] = StoryAgentCrew(
            supabase_url=os.getenv("SUPABASE_URL"),
            supabase_key=os.getenv("SUPABASE_SERVICE_ROLE_KEY"),
            story_id=story_id
        )
    return agent_crews[story_id]

# ============ API 端点 ============

@app.get("/")
async def root():
    return {
        "service": "Mock Drama Agent Server (CrewAI)",
        "status": "running",
        "version": "2.0.0",
        "framework": "CrewAI"
    }

@app.post("/api/session/create", response_model=SessionResponse)
async def create_session(request: CreateSessionRequest):
    """创建新游戏会话"""
    try:
        session = db_manager.create_session(
            user_id=request.user_id,
            story_id=request.story_id
        )
        
        return SessionResponse(
            session_id=session["id"],
            story_id=session["story_id"],
            current_chapter=session["current_chapter"],
            current_situation=session["current_situation"],
            message="会话创建成功"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/story/action", response_model=ActionResponse)
async def process_action(request: ActionRequest, background_tasks: BackgroundTasks):
    """
    处理用户行动（同步返回）
    """
    try:
        # 获取会话信息
        session = db_manager.get_session(request.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="会话不存在")
        
        if session["is_completed"]:
            raise HTTPException(status_code=400, detail="游戏已结束")
        
        # 获取 Agent Crew
        agent = get_agent_crew(session["story_id"])
        
        # 处理用户行动
        result = await agent.process_user_action(
            session_id=request.session_id,
            user_input=request.user_input
        )
        
        # 后台保存消息
        background_tasks.add_task(
            db_manager.save_message,
            session_id=request.session_id,
            role="user",
            content=request.user_input
        )
        background_tasks.add_task(
            db_manager.save_message,
            session_id=request.session_id,
            role="assistant",
            content=result["story"]
        )
        
        return ActionResponse(**result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/session/{session_id}")
async def get_session(session_id: str):
    """获取会话信息"""
    try:
        session = db_manager.get_session(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="会话不存在")
        return session
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/session/{session_id}/history")
async def get_history(session_id: str, limit: int = 20):
    """获取对话历史"""
    try:
        messages = db_manager.get_messages(session_id, limit)
        return {"messages": messages}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============ 健康检查 ============

@app.get("/health")
async def health_check():
    """健康检查端点"""
    try:
        # 检查 Redis 连接
        if redis_client:
            await redis_client.ping()
            redis_status = "healthy"
        else:
            redis_status = "not_initialized"
    except:
        redis_status = "unhealthy"
    
    # 检查数据库连接
    try:
        if db_manager:
            db_manager.health_check()
            db_status = "healthy"
        else:
            db_status = "not_initialized"
    except:
        db_status = "unhealthy"
    
    overall_status = "healthy" if redis_status == "healthy" and db_status == "healthy" else "unhealthy"
    
    return {
        "status": overall_status,
        "redis": redis_status,
        "database": db_status,
        "version": "2.0.0",
        "framework": "CrewAI"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)))
