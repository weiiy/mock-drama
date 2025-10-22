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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drama Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DialoguePage(title: '崇祯剧本'),
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
  const DialoguePage({super.key, required this.title});

  final String title;

  @override
  State<DialoguePage> createState() => _DialoguePageState();
}

class _DialoguePageState extends State<DialoguePage> {
  final List<ChatMessage> _messages = [
    const ChatMessage(
      role: MessageRole.system,
      content: '话说崇祯元年，你新登大位，面临阉党余波、东林党纠纷、后金入侵与民间灾荒的四重危机。请以皇帝视角描述你的应对思路。',
    ),
  ];
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
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final client = _supabaseClient;
    if (client == null) return;

    try {
      // 获取或创建用户
      final authResponse = await client.auth.signInAnonymously();
      _userId = authResponse.user?.id;

      if (_userId != null) {
        // 创建新会话
        final sessionResponse = await client.from('chat_sessions').insert({
          'user_id': _userId,
          'title': '崇祯帝之旅',
          'synopsis': '大明王朝模拟剧本',
        }).select().single();

        setState(() {
          _sessionId = sessionResponse['id'] as String?;
        });
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
    final client = _supabaseClient;
    if (client == null) {
      _updateStreamingMessage('Supabase 未初始化，请先在 .env 填写 SUPABASE_URL 与 SUPABASE_ANON_KEY。');
      return;
    }

    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
      
      if (supabaseUrl == null || supabaseAnonKey == null) {
        _updateStreamingMessage('缺少 Supabase 配置');
        return;
      }

      final url = Uri.parse('$supabaseUrl/functions/v1/orchestrator');
      final request = http.Request('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
      });
      
      request.body = jsonEncode({
        'messages': _messages.where((m) => m.role != MessageRole.assistant || m.content.isNotEmpty).map((m) => m.toJson()).toList(),
        'sessionId': _sessionId,
        'userId': _userId,
      });

      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        _updateStreamingMessage('Edge Function 调用失败: ${streamedResponse.statusCode} $errorBody');
        return;
      }

      // 解析 SSE 流
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);
          
          if (data == '[DONE]') {
            break;
          }
          
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            if (json.containsKey('chunk')) {
              _updateStreamingMessage(json['chunk'] as String);
            } else if (json.containsKey('error')) {
              _updateStreamingMessage('错误: ${json['error']}');
            }
          } catch (e) {
            debugPrint('解析 SSE 数据失败: $e');
          }
        }
      }
    } catch (error) {
      _updateStreamingMessage('Edge Function 未部署或调用失败：$error');
    }
  }

  void _updateStreamingMessage(String content) {
    if (!mounted) return;
    setState(() {
      // 更新最后一条消息
      if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
        _messages[_messages.length - 1] = ChatMessage(
          role: MessageRole.assistant,
          content: content,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                    child: Text(message.content),
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
                      hintText: '输入你作为崇祯皇帝的决策...',
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
