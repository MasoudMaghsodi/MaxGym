import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // پشتیبانی از dart-define برای امنیت در محیط Production به همراه کلیدهای پروژه شما
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pnuyylukurndiflgzxmo.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_WwWRmaKsCVi9tlvlH3Kf1g_63q_rlid',
  );

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// راهاندازی ایمن بدون مسدود کردن اپ در محیط بدون اینترنت باشگاه
  static Future<void> initializeSafely() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      // ارسال پینگ Heartbeat در پسزمینه برای جلوگیری از Pause شدن پلن رایگان Supabase
      _sendBackgroundHeartbeat();
    } catch (e) {
      debugPrint('Offline Mode Active - Supabase Init Deferred: $e');
      _isInitialized = false;
    }
  }

  static SupabaseClient? get clientOrNull =>
      _isInitialized ? Supabase.instance.client : null;

  static Future<void> _sendBackgroundHeartbeat() async {
    try {
      final client = clientOrNull;
      if (client == null) return;
      await client.from('app_heartbeat').upsert({
        'id': 1,
        'last_ping': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // اگر اینترنت قطع باشد، در سکوت نادیده گرفته میشود تا تجربه کاربری مختل نشود
    }
  }
}
