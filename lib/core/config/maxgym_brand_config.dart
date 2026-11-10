class MaxGymBrandConfig {
  /// ۱. دامنه فعلی کلادفلر شما (هر زمان دامنه جدید باشگاه را گرفتید فقط همین رشته را تغییر دهید)
  static const String activeDomain = String.fromEnvironment(
    'APP_DOMAIN',
    defaultValue: 'privatepath.ir',
  );

  /// ۲. نام کاربری و ریپازیتوری گیتهاب شما (برای لینک دانلود خودکار آخرین نسخه APK از GitHub Releases)
  static const String githubOwnerAndRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: 'MasoudMaghsodi/MaxGym',
  );

  static const String appName = 'MAX GYM';
  static const String appSlogan = 'NO PAIN NO GAIN • EST. 2019';
  static const String currentAppVersion = '1.2.0';
  static const String bundledLogoAsset = 'assets/images/maxgym_logo.jpeg';

  /// لینک وباپلیکیشن (PWA مخصوص آیفون و مرورگرها روی دامنه کلادفلر شما)
  static String get pwaWebUrl => 'https://$activeDomain';

  /// لینک مستقیم دانلود آخرین فایل نصبی اندروید از GitHub Releases یا دامنه شما
  static String get latestAndroidApkUrl =>
      'https://github.com/$githubOwnerAndRepo/releases/latest/download/MaxGym-Release.apk';
}
