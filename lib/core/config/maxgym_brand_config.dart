class MaxGymBrandConfig {
  /// ۱. سابدامین اختصاصی کلادفلر شما (هر زمان دامنه رسمی باشگاه را گرفتید فقط این خط را تغییر دهید)
  static const String activeDomain = String.fromEnvironment(
    'APP_DOMAIN',
    defaultValue: 'maxgym.privatepath.ir',
  );

  /// ۲. ریپازیتوری رسمی گیتهاب شما
  static const String githubOwnerAndRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: 'MasoudMaghsodi/MaxGym',
  );

  /// ایمیل یا رمز مستر شما برای ورود به پنل مخفی سوپر-ادمین از داخل اپلیکیشن
  static const String superAdminMasterPin = String.fromEnvironment(
    'SUPER_ADMIN_PIN',
    defaultValue: 'MaxGym@Admin2026',
  );

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
