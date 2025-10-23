# Mock Drama Agent Server (CrewAI)

基于 CrewAI 的互动剧本 Agent 服务器，支持章节/局势推进、角色管理、多结局、断点续玩。

## 快速开始

### 1. 安装依赖

```bash
# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/Mac

# 安装依赖
pip install -r requirements.txt
```

### 2. 配置环境变量

```bash
# 复制示例配置
cp .env.example .env

# 编辑配置文件
nano .env
```

### 3. 启动服务

#### 方式 A：本地开发

```bash
# 启动 Redis
docker run -d -p 6379:6379 redis:7-alpine

# 启动服务器
uvicorn main:app --reload
```

#### 方式 B：Docker Compose

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f web
```

### 4. 测试 API

```bash
# 健康检查
curl http://localhost:8000/health

# 创建会话
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "story_id": "chongzhen"}'

# 处理用户行动
curl -X POST http://localhost:8000/api/story/action \
  -H "Content-Type: application/json" \
  -d '{"session_id": "your-session-id", "user_input": "我要铲除魏忠贤"}'
```

## Docker Compose 配置说明

### 环境变量读取

使用 `env_file` 直接读取 `.env` 文件：

```yaml
services:
  web:
    env_file:
      - .env  # 自动读取所有环境变量
```

### Nginx 说明

- **本地开发**：不需要 Nginx，直接访问 `http://localhost:8000`
- **生产环境**：可选使用 Nginx（反向代理、SSL、负载均衡）

生产环境启动：
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

详见 [DOCKER_USAGE.md](DOCKER_USAGE.md)

## API 文档

启动服务后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 部署

详见 [DEPLOYMENT.md](../DEPLOYMENT.md)

### 快速部署选项

| 方案 | 成本 | 难度 | 推荐度 |
|------|------|------|--------|
| Docker Compose + VPS | $7/月 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| Fly.io | $20/月 | ⭐ | ⭐⭐⭐⭐ |

## 项目结构

```
agent-server/
├── main.py                    # FastAPI 主服务器
├── crewai_story_agent.py     # CrewAI Agent 实现
├── database.py                # 数据库管理器
├── character_knowledge.py     # 角色知识库
├── requirements.txt           # Python 依赖
├── Dockerfile                 # Docker 镜像
├── docker-compose.yml         # Docker Compose 配置
├── fly.toml                   # Fly.io 配置
└── .env.example               # 环境变量示例
```

## 技术栈

- **Web 框架**: FastAPI
- **Agent 框架**: CrewAI
- **LLM**: Replicate (Llama 3.1 70B)
- **数据库**: Supabase (PostgreSQL)
- **缓存**: Redis
- **部署**: Docker / Fly.io

## 功能特性

✅ 章节/局势推进系统  
✅ 角色状态管理  
✅ 多结局生成  
✅ 断点续玩  
✅ 向量知识库  
✅ 实时健康检查  

## 开发

```bash
# 运行测试
pytest

# 代码格式化
black .
isort .

# 类型检查
mypy .
```

## License

MIT
