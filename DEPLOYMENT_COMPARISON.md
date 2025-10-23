# 部署方案对比

## 三种部署方式详细对比

### 1. Docker Compose + 自建 VPS ⭐⭐⭐⭐⭐

#### 优势
- ✅ **成本最低**：$7/月（Hetzner VPS）
- ✅ **完全控制**：可以自由配置所有参数
- ✅ **无流量限制**：不限制请求数和流量
- ✅ **学习价值**：了解完整的部署流程
- ✅ **易于调试**：可以直接 SSH 登录查看日志

#### 劣势
- ❌ **需要运维**：需要自己维护服务器
- ❌ **无自动扩容**：流量增加需要手动升级
- ❌ **单点故障**：服务器宕机则服务不可用
- ❌ **需要配置**：Nginx、SSL、防火墙等

#### 适用场景
- 独立开发者
- 预算有限
- 用户量 < 1000
- 希望完全控制

#### 部署步骤

```bash
# 1. 购买 VPS（Hetzner）
# 访问 https://www.hetzner.com/cloud
# 选择 CPX21: 3 vCPU, 4GB RAM, €5.83/月

# 2. SSH 登录
ssh root@your-server-ip

# 3. 安装 Docker
curl -fsSL https://get.docker.com | sh
apt install docker-compose -y

# 4. 克隆代码
git clone https://github.com/your-repo/mock-drama.git
cd mock-drama/agent-server

# 5. 配置环境变量
cp .env.example .env
nano .env  # 填写配置

# 6. 启动服务
docker-compose up -d

# 7. 配置 Nginx 和 SSL
apt install nginx certbot python3-certbot-nginx -y
# 配置 Nginx（见 DEPLOYMENT.md）
certbot --nginx -d your-domain.com
```

#### 月成本明细

| 项目 | 成本 |
|------|------|
| Hetzner VPS (CPX21) | €5.83 ≈ $6.5 |
| 域名 (Cloudflare) | $10/年 ≈ $0.83 |
| SSL (Let's Encrypt) | $0 |
| **总计** | **$7.33/月** |

---

### 2. Fly.io ⭐⭐⭐⭐

#### 优势
- ✅ **零运维**：完全托管，无需维护
- ✅ **自动扩缩容**：根据流量自动调整
- ✅ **全球 CDN**：多区域部署
- ✅ **自动 SSL**：免费 HTTPS
- ✅ **简单部署**：一条命令即可
- ✅ **免费额度**：有一定免费额度

#### 劣势
- ❌ **成本较高**：$20/月起
- ❌ **依赖平台**：受平台限制
- ❌ **调试困难**：无法直接 SSH
- ❌ **配置受限**：某些配置无法修改

#### 适用场景
- 追求便利性
- 需要全球部署
- 用户量 100-10000
- 预算充足

#### 部署步骤

```bash
# 1. 安装 Fly CLI
brew install flyctl  # Mac
# 或
curl -L https://fly.io/install.sh | sh  # Linux

# 2. 登录
flyctl auth login

# 3. 初始化项目
cd agent-server
flyctl launch
# 选择区域: hkg (Hong Kong)
# 选择 Redis: Yes

# 4. 设置环境变量
flyctl secrets set SUPABASE_URL=https://your-project.supabase.co
flyctl secrets set SUPABASE_SERVICE_ROLE_KEY=your-key
flyctl secrets set REPLICATE_API_TOKEN=your-token

# 5. 部署
flyctl deploy

# 6. 查看状态
flyctl status
flyctl logs
```

#### 月成本明细

| 项目 | 配置 | 成本 |
|------|------|------|
| Compute | 2 CPU, 2GB RAM × 1 | $15 |
| Redis | 256MB | $5 |
| 流量 | 100GB | $0 (免费) |
| SSL | 自动 | $0 |
| **总计** | | **$20/月** |

---

### 3. 本地开发 ⭐⭐⭐

#### 优势
- ✅ **完全免费**：无任何费用
- ✅ **快速迭代**：修改代码立即生效
- ✅ **易于调试**：可以使用 IDE 调试
- ✅ **无限制**：不受任何限制

#### 劣势
- ❌ **仅限开发**：无法对外提供服务
- ❌ **不稳定**：电脑关机则服务停止
- ❌ **无法访问**：外网无法访问

#### 适用场景
- 开发测试
- 功能验证
- 学习研究

#### 启动步骤

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 启动 Redis
docker run -d -p 6379:6379 redis:7-alpine

# 3. 配置环境变量
cp .env.example .env
nano .env

# 4. 启动服务
uvicorn main:app --reload

# 5. 访问
open http://localhost:8000/docs
```

---

## 详细对比表

| 特性 | Docker Compose + VPS | Fly.io | 本地开发 |
|------|---------------------|--------|---------|
| **成本** | $7/月 | $20/月 | $0 |
| **部署难度** | ⭐⭐ | ⭐ | ⭐ |
| **运维难度** | ⭐⭐⭐ | ⭐ | ⭐ |
| **扩展性** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ |
| **稳定性** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ |
| **控制度** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **全球访问** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ |
| **自动扩容** | ❌ | ✅ | ❌ |
| **SSL** | 需配置 | 自动 | ❌ |
| **监控** | 需配置 | 内置 | 手动 |
| **日志** | 需配置 | 内置 | 控制台 |
| **备份** | 需配置 | 自动 | 手动 |

---

## 推荐方案

### 阶段 1：开发测试（0-10 用户）
**推荐**：本地开发
- 成本：$0
- 快速迭代，验证功能

### 阶段 2：小规模上线（10-100 用户）
**推荐**：Docker Compose + Hetzner VPS
- 成本：$7/月
- 性价比最高
- 足够稳定

### 阶段 3：成长期（100-1000 用户）
**推荐**：继续使用 VPS，升级配置
- 成本：$15-30/月
- 升级到 CPX31 (4 vCPU, 8GB RAM)
- 添加监控和备份

### 阶段 4：扩展期（1000+ 用户）
**推荐**：迁移到 Fly.io 或 Kubernetes
- 成本：$50-200/月
- 自动扩缩容
- 全球部署

---

## 实际案例

### 案例 1：独立开发者

**需求**：
- 预算有限（< $10/月）
- 用户量小（< 50 日活）
- 希望学习完整流程

**方案**：Docker Compose + Hetzner VPS
```
成本：$7/月
配置：3 vCPU, 4GB RAM
性能：可支持 50-100 日活用户
```

**实际效果**：
- ✅ 成本可控
- ✅ 性能足够
- ✅ 学到很多运维知识

### 案例 2：快速上线

**需求**：
- 追求便利性
- 不想管运维
- 预算充足（$20-50/月）

**方案**：Fly.io
```
成本：$20/月
配置：2 CPU, 2GB RAM
性能：可支持 100-500 日活用户
```

**实际效果**：
- ✅ 部署简单（5 分钟）
- ✅ 零运维
- ✅ 自动扩容

---

## 迁移路径

### 从本地开发 → VPS

```bash
# 1. 购买 VPS
# 2. 配置 Docker Compose
# 3. 推送代码
git push origin main

# 4. 服务器拉取代码
ssh root@your-server
cd /opt/mock-drama
git pull
docker-compose up -d
```

### 从 VPS → Fly.io

```bash
# 1. 安装 Fly CLI
# 2. 初始化项目
flyctl launch

# 3. 迁移环境变量
flyctl secrets set SUPABASE_URL=...

# 4. 部署
flyctl deploy

# 5. 更新 DNS
# 将域名指向 Fly.io
```

### 从 Fly.io → VPS

```bash
# 1. 导出数据
# 2. 配置 VPS
# 3. 导入数据
# 4. 更新 DNS
```

---

## 成本优化建议

### 1. LLM 成本优化

```python
# 使用缓存减少 LLM 调用
cache_hit_rate = 30%  # 缓存命中率
original_cost = $100/月
optimized_cost = $100 × (1 - 0.3) = $70/月
节省：$30/月
```

### 2. 服务器成本优化

```bash
# 使用 Spot 实例（Hetzner 无，但其他平台有）
# 或选择更便宜的区域
# 或使用按需计费
```

### 3. 数据库成本优化

```sql
-- 定期归档旧数据
-- 使用 Supabase Free Plan（500MB）
-- 超出后使用对象存储（$0.015/GB）
```

---

## 总结

| 场景 | 推荐方案 | 月成本 |
|------|---------|--------|
| 开发测试 | 本地开发 | $0 |
| 小规模上线 | VPS + Docker | $7 |
| 快速上线 | Fly.io | $20 |
| 大规模运营 | Kubernetes | $100+ |

**最佳实践**：
1. 开始用本地开发
2. 上线用 VPS（Hetzner）
3. 成长后考虑 Fly.io
4. 大规模时用 Kubernetes

**关键建议**：
- ✅ 从简单开始
- ✅ 根据需求扩展
- ✅ 监控成本和性能
- ✅ 定期备份数据
