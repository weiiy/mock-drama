import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl != null &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } else {
    debugPrint('Supabase 未初始化，请检查 .env 配置。');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 互动剧本',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StorySelectionPage(),
    );
  }
}

// 剧本数据模型
class Story {
  final String id;
  final String title;
  final String description;
  final String coverImage;
  final String systemPrompt;
  final List<String> tags;
  final String edgeFunctionName; // 对应的 Edge Function 名称

  const Story({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImage,
    required this.systemPrompt,
    required this.tags,
    required this.edgeFunctionName,
  });
}

// 示例剧本数据
final List<Story> availableStories = [
  Story(
    id: 'chongzhen',
    title: '崇祯皇帝',
    description: '崇祯元年，天启皇帝暴毙，你仓促即位。朝堂上，阉党余波仍掌锦衣卫，东林士人与勋戚互相攻讦；边疆上，后金铁骑连陷辽东，山海关风雨飘摇；民间因连年旱涝、蝗灾与赋役失序而生怨，西北、江淮盗乱四起。你能否力挽狂澜，拯救大明王朝？',
    coverImage: '🏯',
    systemPrompt: '崇祯元年，天启皇帝暴毙，你仓促即位。朝堂上，阉党余波仍掌锦衣卫，东林士人与勋戚互相攻讦；边疆上，后金铁骑连陷辽东，山海关风雨飘摇；民间因连年旱涝、蝗灾与赋役失序而生怨，西北、江淮盗乱四起。请先以皇帝视角概述大明当下的危局，然后提出你筹划的首要对策与施政重点。',
    tags: ['历史', '策略', '明朝'],
    edgeFunctionName: 'chongzhen',
  ),
  Story(
    id: 'fantasy_adventure',
    title: '魔法学院',
    description: '你是一名刚入学的魔法学徒，在神秘的阿卡纳魔法学院开始了你的冒险。学院中隐藏着古老的秘密，黑暗势力蠢蠢欲动。你将学习魔法、结交伙伴，揭开学院背后的真相。',
    coverImage: '🔮',
    systemPrompt: '你是阿卡纳魔法学院的一年级新生。今天是开学第一天，你站在宏伟的学院大门前，手中握着录取通知书。学院的高塔直插云霄，空气中弥漫着魔法的气息。请描述你的角色背景，以及你对魔法学院的第一印象和期待。',
    tags: ['奇幻', '冒险', '魔法'],
    edgeFunctionName: 'fantasy',
  ),
  Story(
    id: 'cyberpunk',
    title: '赛博朋克 2177',
    description: '2177年，人类与AI共存的时代。你是一名赛博侦探，在霓虹闪烁的巨型都市中追查真相。企业巨头操控一切，地下黑客反抗压迫。在这个光怪陆离的世界，你将如何选择自己的道路？',
    coverImage: '🤖',
    systemPrompt: '2177年，新东京。你是一名独立赛博侦探，刚刚接到一个神秘委托。委托人声称发现了某大型企业的黑幕，但在约定见面前失踪了。你的义体改造让你拥有超越常人的能力，但也让你背负沉重的债务。请描述你的角色设定和当前处境。',
    tags: ['科幻', '悬疑', '赛博朋克'],
    edgeFunctionName: 'cyberpunk',
  ),
];

// 剧本选择页面
class StorySelectionPage extends StatelessWidget {
  const StorySelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择你的冒险'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '探索无限可能的故事',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '每个选择都会影响故事的走向',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: availableStories.length,
                itemBuilder: (context, index) {
                  final story = availableStories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StoryDetailPage(story: story),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 封面图标
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  story.coverImage,
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 剧本信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    story.title,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    story.description,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: story.tags.map((tag) {
                                      return Chip(
                                        label: Text(tag),
                                        labelStyle: const TextStyle(fontSize: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 剧本详情页面
class StoryDetailPage extends StatelessWidget {
  final Story story;

  const StoryDetailPage({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(story.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面区域
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  story.coverImage,
                  style: const TextStyle(fontSize: 100),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    story.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 标签
                  Wrap(
                    spacing: 8,
                    children: story.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // 剧本简介
                  Text(
                    '剧本简介',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    story.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 开始游戏按钮
                  FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DialoguePage(
                            story: story,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('开始冒险'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MessageRole { system, user, assistant }

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final MessageRole role;
  final String content;

  Map<String, String> toJson() => {'role': role.name, 'content': content};
}

class DialoguePage extends StatefulWidget {
  const DialoguePage({super.key, required this.story});

  final Story story;

  @override
  State<DialoguePage> createState() => _DialoguePageState();
}

class _DialoguePageState extends State<DialoguePage> {
  late final List<ChatMessage> _messages;
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  String? _sessionId;
  String? _userId;

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _messages = [
      ChatMessage(
        role: MessageRole.system,
        content: widget.story.systemPrompt,
      ),
    ];
    _initializeSession();
  }

  String _extractSection(String source, String start, String? end) {
    final startIndex = source.indexOf(start);
    if (startIndex == -1) {
      return '';
    }
    final from = startIndex + start.length;
    final endIndex = end == null ? -1 : source.indexOf(end, from);
    if (endIndex == -1) {
      return source.substring(from);
    }
    return source.substring(from, endIndex);
  }

  List<MapEntry<String, String>> _parseAssistantSections(String content) {
    const headers = [
      '回复：',
      '📖剧情：',
      '📊成果：',
      '💡 提示：',
    ];
    final sections = <MapEntry<String, String>>[];
    for (var i = 0; i < headers.length; i++) {
      final start = headers[i];
      final end = i + 1 < headers.length ? headers[i + 1] : null;
      final text = _extractSection(content, start, end).trim();
      if (text.isNotEmpty) {
        sections.add(MapEntry(start, text));
      }
    }
    return sections;
  }

  Widget _buildAssistantContent(BuildContext context, String content) {
    final sections = _parseAssistantSections(content);
    if (sections.isEmpty) {
      return Text(content);
    }
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final entry = sections[i];
      children.add(
        Text(
          entry.key,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
      final paragraphs = entry.value.split(RegExp(r'\n\s*\n'));
      for (var j = 0; j < paragraphs.length; j++) {
        children.add(Padding(
          padding: EdgeInsets.only(top: j == 0 ? 6 : 10),
          child: Text(paragraphs[j]),
        ));
      }
      if (i != sections.length - 1) {
        children.add(const SizedBox(height: 14));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildMessageContent(BuildContext context, ChatMessage message) {
    if (message.role == MessageRole.assistant) {
      return _buildAssistantContent(context, message.content);
    }
    return Text(message.content);
  }

  Future<void> _initializeSession() async {
    try {
      // 生成临时用户 ID
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      
      // 调用 Python 后端创建会话
      final agentServerUrl = dotenv.env['AGENT_SERVER_URL'] ?? 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$agentServerUrl/api/session/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'story_id': widget.story.id, // 使用剧本 ID
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _sessionId = data['session_id'] as String?;
        });
        debugPrint('会话已创建: $_sessionId');
      } else {
        debugPrint('创建会话失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('初始化会话失败: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }
    
    setState(() {
      _isSending = true;
      _messages.add(ChatMessage(role: MessageRole.user, content: text));
      _controller.clear();
      // 添加一个占位消息用于流式显示
      _messages.add(const ChatMessage(role: MessageRole.assistant, content: ''));
    });
    
    await _invokeEdgeFunctionStream();
    
    if (!mounted) return;
    
    setState(() {
      _isSending = false;
    });
  }

  Future<void> _invokeEdgeFunctionStream() async {
    if (_sessionId == null) {
      _updateStreamingMessage('会话未初始化');
      return;
    }

    try {
      final agentServerUrl = dotenv.env['AGENT_SERVER_URL'] ?? 'http://localhost:8000';
      
      // 获取用户最后一条消息
      final userMessage = _messages.where((m) => m.role == MessageRole.user).last.content;
      
      // 调用 Python 后端处理用户行动
      final url = Uri.parse('$agentServerUrl/api/story/action');
      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
      });
      
      request.body = jsonEncode({
        'session_id': _sessionId,
        'user_input': userMessage,
      });

      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        _updateStreamingMessage('Agent Server 调用失败: ${streamedResponse.statusCode} $errorBody');
        return;
      }

      // 读取完整响应
      final responseBody = await streamedResponse.stream.bytesToString();
      final responseData = jsonDecode(responseBody) as Map<String, dynamic>;
      
      // 获取剧情内容
      final story = responseData['story'] as String?;
      if (story != null) {
        _updateStreamingMessage(story, isFinal: true);
        
        // 检查章节状态
        final chapterStatus = responseData['chapter_status'] as String?;
        if (chapterStatus == 'ending') {
          // 游戏结束
          final ending = responseData['ending'] as Map<String, dynamic>?;
          if (ending != null) {
            debugPrint('游戏结束，结局类型: ${ending['ending_type']}');
          }
        } else if (chapterStatus == 'next_chapter') {
          debugPrint('进入下一章节');
        }
      } else {
        _updateStreamingMessage('未收到剧情响应', isFinal: true);
      }
    } catch (error) {
      _updateStreamingMessage('Agent Server 调用失败：$error');
    }
  }

  void _updateStreamingMessage(String content, {bool isFinal = false}) {
    if (!mounted) return;
    setState(() {
      // 更新最后一条消息
      if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
        _messages[_messages.length - 1] = ChatMessage(
          role: MessageRole.assistant,
          content: content,
        );
      }
      if (isFinal) {
        _isSending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.story.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == MessageRole.user;
                final alignment = isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft;
                final color = switch (message.role) {
                  MessageRole.system => Colors.grey.shade300,
                  MessageRole.user => Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  MessageRole.assistant => Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                };
                return Align(
                  alignment: alignment,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildMessageContent(context, message),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isSending,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '输入你的选择和行动...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSending ? null : _sendMessage,
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('发送'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
