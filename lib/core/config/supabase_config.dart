import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ذخیرهساز رمزنگاریشده سختافزاری (AES-256 Keystore / Keychain) برای محافظت از JWT و Refresh Token
/// مطابق با استاندارد OWASP M1 & M9
class SecureSupabaseLocalStorage extends LocalStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _sessionKey = 'SUPABASE_PERSIST_SESSION_SECURE_KEY';

  const SecureSupabaseLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    return await _storage.read(key: _sessionKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    return await _storage.containsKey(key: _sessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _sessionKey);
  }
}

class SupabaseConfig {
  // کلیدهای عمومی فقط از طریق متغیرهای محیطی کامپایل (dart-define) تزریق میشوند
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

  static Future<void> initializeSafely() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(
          // استفاده از پروتکل امنیتی PKCE برای جلوگیری از شنود و سرقت کد احراز هویت (OWASP M3/M5)
          authFlowType: AuthFlowType.pkce,
          localStorage: SecureSupabaseLocalStorage(),
          autoRefreshToken: true,
        ),
        debug: false, // غیرفعال کردن لاگهای شبکه در کنسول برای جلوگیری از نشت توکن در Logcat (OWASP M9)
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase Offline Init Deferred.');
      _isInitialized = false;
    }
  }

  static SupabaseClient? get clientOrNull =>
      _isInitialized ? Supabase.instance.client : null;
}
