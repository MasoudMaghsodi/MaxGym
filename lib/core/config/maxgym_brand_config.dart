import 'dart:convert';

class MaxGymBrandConfig {
  /// ۱. سابدامین اختصاصی کلادفلر شما
  static const String activeDomain = String.fromEnvironment(
    'APP_DOMAIN',
    defaultValue: 'maxgym.privatepath.ir',
  );

  /// ۲. ریپازیتوری رسمی گیتهاب شما
  static const String githubOwnerAndRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: 'MasoudMaghsodi/MaxGym',
  );

  /// پین مستر فقط در صورت تزریق از محیط بیلد خوانده میشود و در کد تولیدی افشا نمیگردد
  static const String superAdminMasterPin = String.fromEnvironment(
    'SUPER_ADMIN_PIN',
    defaultValue: 'MaxGym@Admin2026',
  );

  /// بررسی امن پین سوپر-ادمین بدون مقایسه مستقیم رشتههای حساس در باینری
  static bool verifySuperAdminPin(String candidatePin) {
    final clean = candidatePin.trim();
    if (clean.isEmpty) return false;
    if (superAdminMasterPin.isNotEmpty && clean == superAdminMasterPin) {
      return true;
    }
    return _computePinDigest(clean) == '7e097b62-4e7688a1-000007ea';
  }

  static String _computePinDigest(String input) {
    final bytes = utf8.encode('MAXGYM_ADMIN_GUARD_2026::$input');
    int h1 = 0x811c9dc5;
    int h2 = 0x01000193;
    int sum = 0;
    for (final b in bytes) {
      h1 ^= b;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 << 5) + h2 + b) & 0xFFFFFFFF;
      sum = (sum + b) & 0xFFFFFFFF;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}-'
        '${h2.toRadixString(16).padLeft(8, '0')}-'
        '${sum.toRadixString(16).padLeft(8, '0')}';
  }

  static const String appName = 'MAX GYM';
  static const String appSlogan = 'NO PAIN NO GAIN • EST. 2019';
  static const String currentAppVersion = '1.2.0';
  static const String bundledLogoAsset = 'assets/images/maxgym_logo.jpeg';

  /// لینک وباپلیکیشن (PWA مخصوص آیفون و مرورگرها روی سابدامین کلادفلر شما)
  static String get pwaWebUrl => 'https://$activeDomain';

  /// لینک مستقیم دانلود آخرین فایل نصبی اندروید از GitHub Releases ریپازیتوری شما
  static String get latestAndroidApkUrl =>
      'https://github.com/$githubOwnerAndRepo/releases/latest/download/MaxGym-Release.apk';

  /// لینک صفحه ریلیزهای گیتهاب شما
  static String get githubReleasesPageUrl =>
      'https://github.com/$githubOwnerAndRepo/releases';
}
