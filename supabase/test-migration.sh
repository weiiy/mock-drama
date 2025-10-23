#!/bin/bash

echo "🧪 测试 SQL 迁移文件"
echo "================================"

SQL_FILE="migrations/20250123_initial_schema.sql"

if [ ! -f "$SQL_FILE" ]; then
    echo "❌ 找不到迁移文件: $SQL_FILE"
    exit 1
fi

echo ""
echo "📄 检查文件: $SQL_FILE"
echo "文件大小: $(wc -c < $SQL_FILE) bytes"
echo "行数: $(wc -l < $SQL_FILE) lines"

echo ""
echo "🔍 检查 SQL 语法..."

# 检查基本语法问题
echo ""
echo "1️⃣ 检查未闭合的括号..."
open_paren=$(grep -o '(' $SQL_FILE | wc -l)
close_paren=$(grep -o ')' $SQL_FILE | wc -l)
if [ $open_paren -eq $close_paren ]; then
    echo "   ✅ 括号匹配: $open_paren 对"
else
    echo "   ❌ 括号不匹配: ( $open_paren vs ) $close_paren"
fi

echo ""
echo "2️⃣ 检查表创建语句..."
table_count=$(grep -c "CREATE TABLE" $SQL_FILE)
echo "   找到 $table_count 个表定义"
grep "CREATE TABLE" $SQL_FILE | sed 's/CREATE TABLE IF NOT EXISTS /   - /'

echo ""
echo "3️⃣ 检查索引创建..."
index_count=$(grep -c "CREATE INDEX" $SQL_FILE)
echo "   找到 $index_count 个索引"

echo ""
echo "4️⃣ 检查触发器..."
trigger_count=$(grep -c "CREATE TRIGGER" $SQL_FILE)
echo "   找到 $trigger_count 个触发器"

echo ""
echo "5️⃣ 检查 RLS 策略..."
policy_count=$(grep -c "CREATE POLICY" $SQL_FILE)
echo "   找到 $policy_count 个策略"

echo ""
echo "6️⃣ 检查常见问题..."

# 检查是否有未定义的列引用
echo "   检查列引用..."
if grep -q "chapter" $SQL_FILE; then
    chapter_in_table=$(grep -A 10 "CREATE TABLE.*chat_messages" $SQL_FILE | grep -c "chapter")
    if [ $chapter_in_table -gt 0 ]; then
        echo "   ✅ chat_messages.chapter 已定义"
    else
        echo "   ⚠️  chat_messages.chapter 可能未定义"
    fi
fi

echo ""
echo "📊 统计信息:"
echo "   - 表: $table_count"
echo "   - 索引: $index_count"
echo "   - 触发器: $trigger_count"
echo "   - RLS 策略: $policy_count"

echo ""
echo "✅ 基本检查完成"
echo ""
echo "💡 建议："
echo "   1. 在 Supabase SQL Editor 中执行"
echo "   2. 如果有错误，查看具体的错误行号"
echo "   3. 可以分段执行（先创建表，再创建索引和策略）"
echo ""
echo "📝 分段执行顺序："
echo "   1. 创建表（第 1-5 节）"
echo "   2. 创建触发器（第 6 节）"
echo "   3. 启用 RLS 和创建策略（第 7 节）"
