#!/bin/bash

echo "🗄️  Supabase 数据库迁移工具"
echo "================================"

# 检查是否安装了 Supabase CLI
if ! command -v supabase &> /dev/null; then
    echo ""
    echo "❌ Supabase CLI 未安装"
    echo ""
    echo "请选择安装方式："
    echo "  Mac:     brew install supabase/tap/supabase"
    echo "  Linux:   curl -fsSL https://raw.githubusercontent.com/supabase/cli/main/install.sh | sh"
    echo "  Windows: scoop install supabase"
    echo ""
    echo "或者手动执行迁移："
    echo "  1. 打开 https://app.supabase.com/"
    echo "  2. 进入 SQL Editor"
    echo "  3. 复制 migrations/20250123_initial_schema.sql 的内容"
    echo "  4. 粘贴并执行"
    exit 1
fi

echo ""
echo "✅ Supabase CLI 已安装"

# 检查是否已登录
echo ""
echo "🔐 检查登录状态..."
if ! supabase projects list &> /dev/null; then
    echo "❌ 未登录 Supabase"
    echo ""
    echo "请先登录："
    supabase login
fi

echo "✅ 已登录"

# 检查是否已链接项目
echo ""
echo "🔗 检查项目链接..."
if [ ! -f ".supabase/config.toml" ]; then
    echo "❌ 未链接到 Supabase 项目"
    echo ""
    echo "请输入你的 Project Ref（在 Supabase Dashboard URL 中）："
    echo "例如：https://app.supabase.com/project/pxgqaijnwbhuumhivclr"
    echo "Project Ref 就是：pxgqaijnwbhuumhivclr"
    echo ""
    read -p "Project Ref: " project_ref
    
    if [ -z "$project_ref" ]; then
        echo "❌ Project Ref 不能为空"
        exit 1
    fi
    
    echo ""
    echo "链接到项目..."
    supabase link --project-ref "$project_ref"
    
    if [ $? -ne 0 ]; then
        echo "❌ 链接失败"
        exit 1
    fi
fi

echo "✅ 项目已链接"

# 应用迁移
echo ""
echo "📦 应用数据库迁移..."
echo ""

# 显示迁移文件
echo "将要执行的迁移："
ls -1 migrations/*.sql

echo ""
read -p "确认执行迁移？(y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "❌ 已取消"
    exit 0
fi

echo ""
echo "执行迁移..."
supabase db push

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 迁移成功！"
    echo ""
    echo "📊 查看迁移状态："
    supabase migration list
    echo ""
    echo "🎉 数据库表已创建！"
    echo ""
    echo "📝 下一步："
    echo "  1. 在 Supabase Dashboard 获取 service_role key"
    echo "  2. 更新 agent-server/.env 文件"
    echo "  3. 重启 Agent Server: docker compose restart web"
else
    echo ""
    echo "❌ 迁移失败"
    echo ""
    echo "💡 可以尝试："
    echo "  1. 手动执行：复制 migrations/20250123_initial_schema.sql 到 Supabase SQL Editor"
    echo "  2. 查看错误日志：supabase db push --debug"
    exit 1
fi
