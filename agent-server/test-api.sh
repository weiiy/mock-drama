#!/bin/bash

echo "🧪 测试 Agent Server API"
echo "================================"

BASE_URL="http://localhost:8000"

# 1. 健康检查
echo ""
echo "1️⃣ 健康检查"
curl -s $BASE_URL/health | jq .

# 2. 根端点
echo ""
echo "2️⃣ 根端点"
curl -s $BASE_URL/ | jq .

# 3. API 文档
echo ""
echo "3️⃣ API 文档"
echo "   Swagger UI: $BASE_URL/docs"
echo "   ReDoc: $BASE_URL/redoc"

# 4. 创建会话（需要配置 .env）
echo ""
echo "4️⃣ 创建会话（需要配置 Supabase）"
echo "   如果已配置 .env，执行："
echo "   curl -X POST $BASE_URL/api/session/create \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"user_id\": \"test_user\", \"story_id\": \"chongzhen\"}'"

echo ""
echo "✅ 基础测试完成！"
echo ""
echo "📝 下一步："
echo "   1. 配置 .env 文件（复制 .env.example）"
echo "   2. 填写 SUPABASE_URL 和 SUPABASE_SERVICE_ROLE_KEY"
echo "   3. 重启服务: docker compose restart web"
echo "   4. 测试完整功能"
