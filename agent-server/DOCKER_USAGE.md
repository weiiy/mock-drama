# Docker Compose 使用指南

## 配置说明

### 环境变量读取方式

Docker Compose 使用 `env_file` 直接读取 `.env` 文件：

```yaml
services:
  web:
    env_file:
      - .env  # 自动读取所有环境变量
    environment:
      - REDIS_URL=redis://redis:6379  # 覆盖特定变量
```

### 优势

✅ **简洁**：不需要逐个列出环境变量  
✅ **统一**：`.env` 文件在本地和 Docker 中都能用  
✅ **安全**：`.env` 文件不会提交到 Git  

---

## 本地开发

### 1. 准备环境变量

```bash
cd agent-server

# 复制示例配置
cp .env.example .env

# 编辑配置
nano .env
```

填写必要的配置：

```env
# .env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
REPLICATE_API_TOKEN=your-replicate-token

# 可选
ANTHROPIC_API_KEY=your-anthropic-key
OPENAI_API_KEY=your-openai-key
```

### 2. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f web

# 查看服务状态
docker-compose ps
```

### 3. 测试

```bash
# 健康检查
curl http://localhost:8000/health

# 创建会话
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "story_id": "chongzhen"}'
```

### 4. 停止服务

```bash
# 停止服务
docker-compose down

# 停止并删除数据卷
docker-compose down -v
```

---

## 生产环境

### 使用 docker-compose.prod.yml

生产环境需要额外配置：

```bash
# 启动生产环境
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 特点：
# - 不使用 --reload（性能更好）
# - 运行多个 worker
# - 可选添加 Nginx
# - 不挂载代码卷
```

### Nginx 使用场景

**本地开发**：❌ 不需要 Nginx
- 直接访问 `http://localhost:8000`
- 简单快速

**生产环境**：✅ 可选使用 Nginx
- 反向代理
- 负载均衡
- SSL 终止
- 静态文件服务

如果需要 Nginx，使用：
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 常用命令

### 查看日志

```bash
# 实时日志
docker-compose logs -f web

# 最近 100 行
docker-compose logs --tail=100 web

# 所有服务
docker-compose logs -f
```

### 重启服务

```bash
# 重启 web 服务
docker-compose restart web

# 重启所有服务
docker-compose restart
```

### 进入容器

```bash
# 进入 web 容器
docker-compose exec web bash

# 进入 Redis
docker-compose exec redis redis-cli
```

### 查看资源使用

```bash
# 查看容器资源
docker stats

# 查看 Docker Compose 服务
docker-compose ps
```

### 清理

```bash
# 停止并删除容器
docker-compose down

# 删除数据卷
docker-compose down -v

# 删除镜像
docker-compose down --rmi all
```

---

## 环境变量优先级

Docker Compose 的环境变量优先级（从高到低）：

1. **命令行** `-e` 参数
2. **docker-compose.yml** 中的 `environment`
3. **env_file** 指定的文件（`.env`）
4. **Dockerfile** 中的 `ENV`

示例：

```yaml
services:
  web:
    env_file:
      - .env  # 优先级 3
    environment:
      - PORT=8000  # 优先级 2（会覆盖 .env 中的 PORT）
```

---

## 调试技巧

### 1. 查看环境变量

```bash
# 查看容器中的环境变量
docker-compose exec web env | grep SUPABASE
```

### 2. 测试配置

```bash
# 验证配置文件
docker-compose config

# 查看最终配置
docker-compose config --services
```

### 3. 重新构建

```bash
# 重新构建镜像
docker-compose build

# 强制重新构建
docker-compose build --no-cache

# 重新构建并启动
docker-compose up -d --build
```

### 4. 查看网络

```bash
# 查看网络
docker network ls

# 查看容器 IP
docker-compose exec web hostname -i
```

---

## 常见问题

### 1. 环境变量未生效

**问题**：修改 `.env` 后环境变量没有更新

**解决**：
```bash
# 重启容器
docker-compose restart web

# 或重新创建容器
docker-compose up -d --force-recreate
```

### 2. 端口冲突

**问题**：`Error: port 8000 already in use`

**解决**：
```bash
# 查看占用端口的进程
lsof -i :8000

# 修改端口
# 编辑 docker-compose.yml
ports:
  - "8001:8000"  # 映射到 8001
```

### 3. Redis 连接失败

**问题**：`Connection refused to redis:6379`

**解决**：
```bash
# 检查 Redis 是否运行
docker-compose ps redis

# 重启 Redis
docker-compose restart redis

# 查看 Redis 日志
docker-compose logs redis
```

### 4. 代码修改未生效

**问题**：修改代码后没有自动重载

**解决**：
```bash
# 检查是否挂载了代码卷
docker-compose config | grep volumes

# 应该看到：
volumes:
  - ./:/app

# 如果没有，检查 docker-compose.yml
```

---

## 性能优化

### 1. 使用 BuildKit

```bash
# 启用 BuildKit（更快的构建）
export DOCKER_BUILDKIT=1
docker-compose build
```

### 2. 多阶段构建

```dockerfile
# Dockerfile
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]
```

### 3. 缓存依赖

```yaml
# docker-compose.yml
services:
  web:
    volumes:
      - ./:/app
      - pip-cache:/root/.cache/pip  # 缓存 pip

volumes:
  pip-cache:
```

---

## 总结

### 本地开发配置

```yaml
# docker-compose.yml
services:
  web:
    env_file: .env  # ✅ 直接读取 .env
    volumes:
      - ./:/app     # ✅ 挂载代码
    command: uvicorn main:app --reload  # ✅ 自动重载
```

### 生产环境配置

```yaml
# docker-compose.prod.yml
services:
  web:
    env_file: .env
    volumes: []     # ❌ 不挂载代码
    command: uvicorn main:app --workers 4  # ✅ 多 worker
  
  nginx:           # ✅ 添加 Nginx
    image: nginx:alpine
```

### 关键点

- ✅ 使用 `env_file` 读取 `.env`
- ✅ 本地开发不需要 Nginx
- ✅ 生产环境可选 Nginx
- ✅ 代码挂载仅用于开发
