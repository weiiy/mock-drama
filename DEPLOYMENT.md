# 部署教程

## 目录
1. [环境准备](#环境准备)
2. [本地开发](#本地开发)
3. [Docker Compose 部署](#docker-compose-部署)
4. [自建服务器部署](#自建服务器部署)
5. [Fly.io 部署](#flyio-部署)
6. [成本对比](#成本对比)

---

## 环境准备

### 1. 安装依赖

```bash
# Python 3.11+
python --version

# 克隆项目
cd mock-drama/agent-server

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或
venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt
```

### 2. 环境变量配置

创建 `.env` 文件：

```bash
# .env
# Supabase 配置
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Redis 配置
REDIS_URL=redis://localhost:6379

# LLM API Keys
REPLICATE_API_TOKEN=your-replicate-token
ANTHROPIC_API_KEY=your-anthropic-key  # 可选
OPENAI_API_KEY=your-openai-key  # 可选

# 服务器配置
PORT=8000
ENVIRONMENT=development
```

### 3. 数据库设置

在 Supabase 中执行 SQL（见 `QUICKSTART_CREWAI.md`）

---

## 本地开发

### 启动方式

```bash
# 1. 启动 Redis（使用 Docker）
docker run -d -p 6379:6379 redis:7-alpine

# 2. 启动 FastAPI 服务器
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 3. 测试
curl http://localhost:8000/health
```

### 测试 API

```bash
# 创建会话
curl -X POST http://localhost:8000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "story_id": "chongzhen"}'

# 处理用户行动
curl -X POST http://localhost:8000/api/story/action \
  -H "Content-Type: application/json" \
  -d '{"session_id": "your-session-id", "user_input": "我要铲除魏忠贤"}'
```

---

## Docker Compose 部署

### 优势
- ✅ 一键启动所有服务
- ✅ 开发/生产环境一致
- ✅ 易于管理和扩展

### 1. 创建 docker-compose.yml

```yaml
version: '3.8'

services:
  # FastAPI Web 服务器
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      - REDIS_URL=redis://redis:6379
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
      - REPLICATE_API_TOKEN=${REPLICATE_API_TOKEN}
      - PORT=8000
    depends_on:
      - redis
    restart: unless-stopped
    volumes:
      - ./:/app
    command: uvicorn main:app --host 0.0.0.0 --port 8000

  # Redis
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped
    command: redis-server --appendonly yes

  # Nginx (可选 - 用于反向代理)
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro  # SSL 证书
    depends_on:
      - web
    restart: unless-stopped

volumes:
  redis_data:
```

### 2. 创建 Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码
COPY . .

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 3. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f web

# 停止服务
docker-compose down

# 重启服务
docker-compose restart web
```

### 4. 生产环境配置

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  web:
    build: .
    deploy:
      replicas: 2  # 运行 2 个实例
      resources:
        limits:
          cpus: '1'
          memory: 2G
    environment:
      - ENVIRONMENT=production
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

启动生产环境：
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 自建服务器部署

### 推荐配置

**VPS 提供商**：
- Hetzner Cloud (推荐) - €5.83/月
- DigitalOcean - $6/月
- Vultr - $6/月

**服务器配置**：
- CPU: 2-3 vCPU
- RAM: 4GB
- 存储: 80GB SSD
- 系统: Ubuntu 22.04 LTS

### 1. 服务器初始化

```bash
# SSH 登录服务器
ssh root@your-server-ip

# 更新系统
apt update && apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 安装 Docker Compose
apt install docker-compose -y

# 创建部署用户
adduser deploy
usermod -aG docker deploy
su - deploy
```

### 2. 部署代码

```bash
# 克隆代码
git clone https://github.com/your-repo/mock-drama.git
cd mock-drama/agent-server

# 配置环境变量
cp .env.example .env
nano .env  # 编辑配置

# 启动服务
docker-compose up -d
```

### 3. 配置 Nginx 反向代理

```bash
# 安装 Nginx
sudo apt install nginx -y

# 创建配置文件
sudo nano /etc/nginx/sites-available/mock-drama
```

```nginx
# /etc/nginx/sites-available/mock-drama
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/mock-drama /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 4. 配置 SSL (Let's Encrypt)

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx -y

# 获取证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

### 5. 配置系统服务（可选）

如果不使用 Docker，可以创建 systemd 服务：

```bash
# 创建服务文件
sudo nano /etc/systemd/system/mock-drama.service
```

```ini
[Unit]
Description=Mock Drama Agent Server
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/home/deploy/mock-drama/agent-server
Environment="PATH=/home/deploy/mock-drama/agent-server/venv/bin"
ExecStart=/home/deploy/mock-drama/agent-server/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable mock-drama
sudo systemctl start mock-drama
sudo systemctl status mock-drama
```

### 6. 监控和日志

```bash
# 查看 Docker 日志
docker-compose logs -f web

# 查看系统服务日志
sudo journalctl -u mock-drama -f

# 监控资源使用
htop
docker stats
```

---

## Fly.io 部署

### 优势
- ✅ 自动扩缩容
- ✅ 全球 CDN
- ✅ 简单部署
- ✅ 免费额度

### 1. 安装 Fly CLI

```bash
# Mac
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"

# 登录
flyctl auth login
```

### 2. 初始化项目

```bash
cd agent-server

# 初始化 Fly 应用
flyctl launch

# 会提示：
# ? Choose an app name: mock-drama-agent
# ? Choose a region: hkg (Hong Kong)
# ? Would you like to set up a PostgreSQL database? No
# ? Would you like to set up an Upstash Redis database? Yes
```

### 3. 配置 fly.toml

```toml
# fly.toml
app = "mock-drama-agent"
primary_region = "hkg"

[build]
  dockerfile = "Dockerfile"

[env]
  PORT = "8000"

[http_service]
  internal_port = 8000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1
  processes = ["app"]

[[http_service.checks]]
  interval = "10s"
  timeout = "2s"
  grace_period = "5s"
  method = "get"
  path = "/health"

[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 2048
```

### 4. 设置环境变量

```bash
# 设置 secrets
flyctl secrets set SUPABASE_URL=https://your-project.supabase.co
flyctl secrets set SUPABASE_SERVICE_ROLE_KEY=your-key
flyctl secrets set REPLICATE_API_TOKEN=your-token

# 查看 secrets
flyctl secrets list
```

### 5. 部署

```bash
# 部署应用
flyctl deploy

# 查看状态
flyctl status

# 查看日志
flyctl logs

# 打开应用
flyctl open
```

### 6. 扩展和监控

```bash
# 扩展实例数量
flyctl scale count 2

# 扩展资源
flyctl scale vm shared-cpu-2x --memory 4096

# 查看指标
flyctl dashboard
```

### 7. 自定义域名

```bash
# 添加域名
flyctl certs add your-domain.com

# 查看 DNS 记录
flyctl certs show your-domain.com

# 添加 DNS 记录到你的域名提供商
# A 记录: your-domain.com -> Fly.io IP
# AAAA 记录: your-domain.com -> Fly.io IPv6
```

---

## 成本对比

### 方案 A：Docker Compose + 自建 VPS

| 项目 | 提供商 | 配置 | 月成本 |
|------|--------|------|--------|
| VPS | Hetzner | 3 vCPU, 4GB RAM | €5.83 ≈ $6.5 |
| 域名 | Cloudflare | - | $10/年 ≈ $0.83 |
| SSL | Let's Encrypt | - | $0 |
| **总计** | | | **$7.33/月** |

**优势**：
- ✅ 成本最低
- ✅ 完全控制
- ✅ 无流量限制

**劣势**：
- ❌ 需要自己维护
- ❌ 无自动扩缩容
- ❌ 单点故障

### 方案 B：Fly.io

| 项目 | 配置 | 月成本 |
|------|------|--------|
| Compute | 2 CPU, 2GB RAM × 1 | $15 |
| Redis | 256MB | $5 |
| 流量 | 100GB | $0 (免费) |
| **总计** | | **$20/月** |

**优势**：
- ✅ 自动扩缩容
- ✅ 全球 CDN
- ✅ 零运维
- ✅ 自动 SSL

**劣势**：
- ❌ 成本稍高
- ❌ 依赖平台

### 方案 C：混合方案（推荐）

- **开发/测试**：本地 Docker Compose
- **生产环境**：Hetzner VPS ($6.5/月)
- **数据库**：Supabase Free
- **LLM**：Replicate (按使用付费)

**总成本**：约 $10-15/月（包含 LLM 调用）

---

## 部署检查清单

### 部署前

- [ ] 环境变量已配置
- [ ] 数据库表已创建
- [ ] API Keys 已获取
- [ ] 域名已准备（如需要）

### 部署后

- [ ] 健康检查通过 (`/health`)
- [ ] API 测试通过
- [ ] 日志正常
- [ ] 监控配置完成
- [ ] 备份策略制定

### 安全检查

- [ ] 环境变量不在代码中
- [ ] 使用 HTTPS
- [ ] 防火墙已配置
- [ ] 定期更新依赖
- [ ] 日志不包含敏感信息

---

## 故障排查

### 常见问题

#### 1. 连接 Redis 失败

```bash
# 检查 Redis 是否运行
docker ps | grep redis

# 测试连接
redis-cli ping

# 检查环境变量
echo $REDIS_URL
```

#### 2. Supabase 连接失败

```bash
# 检查环境变量
echo $SUPABASE_URL
echo $SUPABASE_SERVICE_ROLE_KEY

# 测试连接
curl $SUPABASE_URL/rest/v1/
```

#### 3. LLM API 调用失败

```bash
# 检查 API Key
echo $REPLICATE_API_TOKEN

# 测试 Replicate
curl https://api.replicate.com/v1/models \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN"
```

#### 4. 内存不足

```bash
# 查看内存使用
free -h
docker stats

# 增加 swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## 下一步

1. ✅ 选择部署方案
2. ✅ 配置环境变量
3. ✅ 执行部署
4. ✅ 测试 API
5. ✅ 配置监控
6. ✅ 集成到 Flutter 客户端

需要帮助？查看详细文档或提 Issue！
