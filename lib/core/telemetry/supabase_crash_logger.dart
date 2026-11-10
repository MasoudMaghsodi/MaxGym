import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';

class SupabaseCrashTelemetry {
  static const _secureStore = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _deviceIdKey = 'MAXGYM_HARDWARE_DEVICE_FINGERPRINT';

  /// راه‌اندازی شنود سراسری کرش‌ها و خطاهای فلاتر (جایگزین بومی Crashlytics)
  static void initializeGlobalErrorHandling() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logExceptionSilently(
        error: details.exceptionAsString(),
        stackTrace: details.stack?.toString() ?? '',
        level: 'flutter_ui_error',
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logExceptionSilently(
        error: error.toString(),
        stackTrace: stack.toString(),
        level: 'async_runtime_error',
      );
      return true;
    };
  }

  /// دریافت یا تولید اثرانگشت یکتای دستگاه (Device ID) برای قفل کردن اکانت روی یک دستگاه
  static Future<String> getOrCreateDeviceFingerprint() async {
    try {
      final existing = await _secureStore.read(key: _deviceIdKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final platformPrefix =
          kIsWeb ? 'WEB' : defaultTargetPlatform.name.toUpperCase();
      final newId =
          'DEV-$platformPrefix-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      await _secureStore.write(key: _deviceIdKey, value: newId);
      return newId;
    } catch (_) {
      return 'DEV-FALLBACK-ID';
    }
  }

  /// ارسال بی‌صدای خطا به جدول app_logs در Supabase
  static Future<void> logExceptionSilently({
    required String error,
    String stackTrace = '',
    String level = 'error',
    String userContext = '',
  }) async {
    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null) return;
      final devId = await getOrCreateDeviceFingerprint();

      await client.from('app_logs').insert({
        'level': level,
        'error_message': error.length > 500 ? error.substring(0, 500) : error,
        'stack_trace':
            stackTrace.length > 1500 ? stackTrace.substring(0, 1500) : stackTrace,
        'platform_info':
            '${kIsWeb ? "Web_PWA" : defaultTargetPlatform.name} ($devId)',
        'user_context': userContext,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
}
