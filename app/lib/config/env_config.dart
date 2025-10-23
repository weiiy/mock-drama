import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 环境配置
class EnvConfig {
  /// Supabase URL
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Supabase Anon Key
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Agent Server URL
  static String get agentServerUrl => dotenv.env['AGENT_SERVER_URL'] ?? 'http://localhost:8000';

  /// API 超时时间（秒）
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '60') ?? 60;

  /// 当前环境
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';

  /// 是否为开发环境
  static bool get isDevelopment => environment == 'development';

  /// 是否为生产环境
  static bool get isProduction => environment == 'production';

  /// 验证配置是否完整
  static bool validate() {
    if (supabaseUrl.isEmpty) {
      print('❌ SUPABASE_URL 未配置');
      return false;
    }
    if (supabaseAnonKey.isEmpty) {
      print('❌ SUPABASE_ANON_KEY 未配置');
      return false;
    }
    if (agentServerUrl.isEmpty) {
      print('❌ AGENT_SERVER_URL 未配置');
      return false;
    }
    print('✅ 环境配置验证通过');
    print('   - Supabase: $supabaseUrl');
    print('   - Agent Server: $agentServerUrl');
    print('   - Environment: $environment');
    return true;
  }
}
