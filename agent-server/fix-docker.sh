#!/bin/bash

echo "🔧 Docker 构建问题修复脚本"
echo "================================"

# 1. 清理 Docker 缓存
echo ""
echo "1️⃣ 清理 Docker 缓存..."
docker system prune -f
docker builder prune -f

# 2. 检查 Docker 守护进程
echo ""
echo "2️⃣ 检查 Docker 状态..."
docker info > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Docker 运行正常"
else
    echo "❌ Docker 未运行，请启动 Docker Desktop"
    exit 1
fi

# 3. 测试网络连接
echo ""
echo "3️⃣ 测试网络连接..."
if curl -s --max-time 5 https://hub.docker.com > /dev/null; then
    echo "✅ 网络连接正常"
else
    echo "⚠️ 网络连接可能有问题"
    echo "   建议："
    echo "   - 检查网络连接"
    echo "   - 配置 Docker 镜像加速器"
fi

# 4. 尝试拉取基础镜像
echo ""
echo "4️⃣ 拉取 Python 基础镜像..."
docker pull python:3.11-slim
if [ $? -eq 0 ]; then
    echo "✅ 镜像拉取成功"
else
    echo "❌ 镜像拉取失败"
    echo "   尝试使用镜像加速器..."
    echo "   请在 Docker Desktop -> Settings -> Docker Engine 中添加："
    echo '   "registry-mirrors": ["https://mirror.ccs.tencentyun.com"]'
    exit 1
fi

# 5. 构建镜像
echo ""
echo "5️⃣ 构建 Docker 镜像..."
docker compose build --no-cache
if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功"
else
    echo "❌ 镜像构建失败"
    exit 1
fi

# 6. 启动服务
echo ""
echo "6️⃣ 启动服务..."
docker compose up -d
if [ $? -eq 0 ]; then
    echo "✅ 服务启动成功"
else
    echo "❌ 服务启动失败"
    exit 1
fi

# 7. 等待服务就绪
echo ""
echo "7️⃣ 等待服务就绪..."
sleep 5

# 8. 测试健康检查
echo ""
echo "8️⃣ 测试健康检查..."
for i in {1..10}; do
    if curl -s http://localhost:8000/health > /dev/null; then
        echo "✅ 服务健康检查通过"
        curl http://localhost:8000/health | jq .
        break
    else
        echo "⏳ 等待服务启动... ($i/10)"
        sleep 2
    fi
done

# 9. 显示日志
echo ""
echo "9️⃣ 服务日志："
echo "================================"
docker compose logs --tail=20 web

echo ""
echo "🎉 完成！"
echo ""
echo "📝 后续操作："
echo "   - 查看日志: docker compose logs -f web"
echo "   - 停止服务: docker compose down"
echo "   - 重启服务: docker compose restart web"
