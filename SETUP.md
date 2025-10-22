# Mock Drama 设置指南

## 1. 启用 Supabase 匿名登录(可选)

如果您想启用数据库持久化功能,需要在 Supabase Dashboard 中启用匿名登录:

### 步骤:
1. 访问 [Supabase Dashboard](https://app.supabase.com)
2. 选择您的项目
3. 进入 **Authentication** → **Providers**
4. 找到 **Anonymous Sign-ins**
5. 点击启用开关

### 如果不启用匿名登录:
- 应用仍然可以正常使用
- AI 对话功能完全正常
- 只是不会保存对话历史到数据库

---

## 2. 安装依赖

### Flutter 应用
```bash
cd app
flutter pub get
```

---

## 3. 配置环境变量

### 应用端 (.env)
在 `app/.env` 文件中配置:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Edge Function 端
在 Supabase 项目中设置以下 secrets:
```bash
supabase secrets set REPLICATE_API_TOKEN=your_replicate_token
```

---

## 4. 部署 Edge Function

```bash
supabase functions deploy orchestrator
```

---

## 5. 运行应用

```bash
cd app
flutter run
```

---

## 6. 测试流式返回

1. 启动应用后,输入任意消息
2. 观察 AI 回复是否实时流式显示
3. (如果启用了匿名登录) 检查 Supabase Dashboard 中的 `chat_sessions` 和 `chat_messages` 表

---

## 常见问题

### Q: 看到 "Anonymous sign-ins are disabled" 错误
**A:** 这是正常的,表示匿名登录未启用。应用仍可正常使用,只是不会保存对话历史。

### Q: 如何查看保存的对话历史?
**A:** 
1. 启用匿名登录(见上方步骤)
2. 在 Supabase Dashboard 中打开 **Table Editor**
3. 查看 `chat_sessions` 和 `chat_messages` 表

### Q: 流式返回不工作
**A:** 
1. 确认 Edge Function 已部署: `supabase functions list`
2. 检查 Replicate API Token 是否正确设置
3. 查看 Edge Function 日志: `supabase functions logs orchestrator`

---

## 技术架构

- **前端**: Flutter (支持 iOS、Android、Web、Desktop)
- **后端**: Supabase Edge Functions (Deno)
- **数据库**: PostgreSQL (Supabase)
- **AI 模型**: OpenAI GPT-5-mini (通过 Replicate)
- **流式传输**: Server-Sent Events (SSE)
