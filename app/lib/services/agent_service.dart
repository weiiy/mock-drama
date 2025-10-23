import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Agent Server 服务
class AgentService {
  final String baseUrl;
  final Duration timeout;

  AgentService({
    String? baseUrl,
    Duration? timeout,
  })  : baseUrl = baseUrl ?? EnvConfig.agentServerUrl,
        timeout = timeout ?? Duration(seconds: EnvConfig.apiTimeout);

  /// 健康检查
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('无法连接到 Agent Server: $e');
    }
  }

  /// 创建游戏会话
  Future<Map<String, dynamic>> createSession({
    required String userId,
    required String storyId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/session/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': userId,
              'story_id': storyId,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? '创建会话失败');
      }
    } catch (e) {
      throw Exception('创建会话失败: $e');
    }
  }

  /// 处理用户行动
  Future<Map<String, dynamic>> processAction({
    required String sessionId,
    required String userInput,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/story/action'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'session_id': sessionId,
              'user_input': userInput,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? '处理行动失败');
      }
    } catch (e) {
      throw Exception('处理行动失败: $e');
    }
  }

  /// 获取会话信息
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/session/$sessionId'),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('会话不存在');
      } else {
        throw Exception('获取会话失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取会话失败: $e');
    }
  }

  /// 获取对话历史
  Future<List<dynamic>> getHistory({
    required String sessionId,
    int limit = 20,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/session/$sessionId/history?limit=$limit'),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['messages'] ?? [];
      } else {
        throw Exception('获取历史失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取历史失败: $e');
    }
  }
}
