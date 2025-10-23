# Flutter 集成 Agent Server 指南

## 环境配置

### 1. 配置 Flutter 环境变量

创建 `app/.env` 文件：

```bash
cd app
cp .env.example .env
nano .env
```

填写配置：

```env
# Supabase 配置
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# Agent Server 配置
# 本地开发
AGENT_SERVER_URL=http://localhost:8000

# API 超时设置（秒）
API_TIMEOUT=60

# 环境标识
ENVIRONMENT=development
```

### 2. 不同环境的配置

#### 本地开发（Docker Compose）

```env
# app/.env
AGENT_SERVER_URL=http://localhost:8000
ENVIRONMENT=development
```

#### iOS 模拟器

```env
# iOS 模拟器无法访问 localhost，需要使用本机 IP
AGENT_SERVER_URL=http://192.168.1.100:8000
ENVIRONMENT=development
```

获取本机 IP：
```bash
# Mac
ifconfig | grep "inet " | grep -v 127.0.0.1

# 或
ipconfig getifaddr en0
```

#### Android 模拟器

```env
# Android 模拟器使用特殊 IP
AGENT_SERVER_URL=http://10.0.2.2:8000
ENVIRONMENT=development
```

#### 生产环境

```env
# 部署到 VPS
AGENT_SERVER_URL=https://your-domain.com
ENVIRONMENT=production

# 或部署到 Fly.io
AGENT_SERVER_URL=https://mock-drama-agent.fly.dev
ENVIRONMENT=production
```

---

## 使用方法

### 1. 在 main.dart 中初始化

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 加载环境变量
  await dotenv.load(fileName: ".env");
  
  // 验证配置
  if (!EnvConfig.validate()) {
    print('⚠️ 环境配置不完整，请检查 .env 文件');
  }
  
  runApp(MyApp());
}
```

### 2. 使用 AgentService

```dart
import 'services/agent_service.dart';

class GamePage extends StatefulWidget {
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final AgentService agentService = AgentService();
  String? sessionId;
  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  // 检查连接
  Future<void> _checkConnection() async {
    try {
      final health = await agentService.healthCheck();
      print('✅ Agent Server 连接成功: ${health['status']}');
    } catch (e) {
      setState(() {
        error = '无法连接到 Agent Server: $e';
      });
      print('❌ $error');
    }
  }

  // 创建会话
  Future<void> _createSession() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await agentService.createSession(
        userId: 'user_123',
        storyId: 'chongzhen',
      );

      setState(() {
        sessionId = result['session_id'];
        isLoading = false;
      });

      print('✅ 会话创建成功: $sessionId');
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      print('❌ 创建会话失败: $e');
    }
  }

  // 处理用户行动
  Future<void> _processAction(String userInput) async {
    if (sessionId == null) {
      print('❌ 请先创建会话');
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await agentService.processAction(
        sessionId: sessionId!,
        userInput: userInput,
      );

      setState(() {
        isLoading = false;
      });

      // 处理返回的剧情
      final story = result['story'];
      final chapterStatus = result['chapter_status'];
      
      print('📖 剧情: $story');
      print('📊 状态: $chapterStatus');

      // 如果游戏结束
      if (chapterStatus == 'ending' && result['ending'] != null) {
        final ending = result['ending'];
        print('🎬 结局: $ending');
      }

    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      print('❌ 处理行动失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('互动剧本')),
      body: Column(
        children: [
          // 连接状态
          if (error != null)
            Container(
              color: Colors.red[100],
              padding: EdgeInsets.all(16),
              child: Text(error!, style: TextStyle(color: Colors.red)),
            ),

          // 创建会话按钮
          if (sessionId == null)
            ElevatedButton(
              onPressed: isLoading ? null : _createSession,
              child: Text('开始游戏'),
            ),

          // 游戏界面
          if (sessionId != null)
            Expanded(
              child: Column(
                children: [
                  Text('会话 ID: $sessionId'),
                  // 对话界面
                  // 选择按钮
                  ElevatedButton(
                    onPressed: isLoading ? null : () {
                      _processAction('我要铲除魏忠贤');
                    },
                    child: Text('铲除魏忠贤'),
                  ),
                ],
              ),
            ),

          // 加载指示器
          if (isLoading)
            CircularProgressIndicator(),
        ],
      ),
    );
  }
}
```

---

## 本地调试流程

### 1. 启动 Agent Server

```bash
# 在 agent-server 目录
cd agent-server

# 启动 Docker Compose
docker-compose up -d

# 查看日志
docker-compose logs -f web

# 测试健康检查
curl http://localhost:8000/health
```

### 2. 配置 Flutter

```bash
# 在 app 目录
cd app

# 配置环境变量
cp .env.example .env
nano .env

# 填写：
# AGENT_SERVER_URL=http://localhost:8000  # Mac/Linux
# AGENT_SERVER_URL=http://10.0.2.2:8000  # Android 模拟器
# AGENT_SERVER_URL=http://192.168.1.100:8000  # iOS 模拟器
```

### 3. 运行 Flutter

```bash
# 运行应用
flutter run

# 或指定设备
flutter run -d chrome  # Web
flutter run -d macos   # macOS
flutter run -d ios     # iOS 模拟器
flutter run -d android # Android 模拟器
```

### 4. 测试连接

在 Flutter 应用中：
1. 点击"开始游戏"创建会话
2. 查看控制台输出
3. 确认连接成功

---

## 常见问题

### 1. 无法连接到 localhost

**问题**：Flutter 应用无法访问 `http://localhost:8000`

**解决方案**：

#### iOS 模拟器
```env
# 使用本机 IP
AGENT_SERVER_URL=http://192.168.1.100:8000
```

#### Android 模拟器
```env
# 使用特殊 IP
AGENT_SERVER_URL=http://10.0.2.2:8000
```

#### Web
```env
# localhost 可以正常使用
AGENT_SERVER_URL=http://localhost:8000
```

### 2. CORS 错误（Web）

**问题**：Web 版本出现 CORS 错误

**解决方案**：Agent Server 已配置 CORS，允许所有来源。如果仍有问题，检查：

```python
# main.py 中的 CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 3. 超时错误

**问题**：请求超时

**解决方案**：

```env
# 增加超时时间
API_TIMEOUT=120
```

或在代码中：
```dart
final agentService = AgentService(
  timeout: Duration(seconds: 120),
);
```

### 4. SSL 证书错误（开发环境）

**问题**：HTTPS 证书验证失败

**解决方案**：开发环境使用 HTTP，不要使用 HTTPS：
```env
AGENT_SERVER_URL=http://localhost:8000  # HTTP
```

---

## 环境切换

### 开发环境 → 生产环境

```bash
# 1. 更新 .env
nano app/.env

# 修改：
AGENT_SERVER_URL=https://your-domain.com
ENVIRONMENT=production

# 2. 重新构建
flutter clean
flutter build apk  # Android
flutter build ios  # iOS
flutter build web  # Web
```

### 使用多个环境文件

```bash
# 创建不同环境的配置
app/.env.development
app/.env.staging
app/.env.production

# 运行时指定
flutter run --dart-define-from-file=.env.development
```

---

## 调试技巧

### 1. 查看网络请求

```dart
import 'package:http/http.dart' as http;

// 添加日志
print('🌐 请求: $url');
print('📤 数据: $body');

final response = await http.post(...);

print('📥 响应: ${response.statusCode}');
print('📄 内容: ${response.body}');
```

### 2. 使用 Charles/Proxyman

抓包工具可以查看所有 HTTP 请求：
- Charles: https://www.charlesproxy.com/
- Proxyman: https://proxyman.io/

### 3. Agent Server 日志

```bash
# 查看实时日志
docker-compose logs -f web

# 查看最近 100 行
docker-compose logs --tail=100 web
```

---

## 生产环境部署

### 1. 部署 Agent Server

```bash
# 方式 1: VPS
ssh root@your-server
cd mock-drama/agent-server
docker-compose up -d

# 方式 2: Fly.io
flyctl deploy
```

### 2. 更新 Flutter 配置

```env
# app/.env
AGENT_SERVER_URL=https://your-domain.com
ENVIRONMENT=production
```

### 3. 构建发布版本

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## 完整示例

见 `app/lib/pages/game_page_example.dart`（待创建）

---

## 下一步

1. ✅ 配置 `app/.env`
2. ✅ 启动 Agent Server（Docker Compose）
3. ✅ 运行 Flutter 应用
4. ✅ 测试创建会话和处理行动
5. ✅ 完成游戏逻辑集成
6. ✅ 部署到生产环境
