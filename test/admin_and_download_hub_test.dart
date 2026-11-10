import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_coach_app/core/config/maxgym_brand_config.dart';
import 'package:pro_coach_app/core/localization/app_localizations.dart';
import 'package:pro_coach_app/core/telemetry/supabase_crash_logger.dart';
import 'package:pro_coach_app/features/admin_and_download/maxgym_hub_and_admin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Admin & Download Hub Tests', () {
    test('MaxGymBrandConfig contains correct domain, repo, and urls', () {
      expect(MaxGymBrandConfig.activeDomain, 'maxgym.privatepath.ir');
      expect(MaxGymBrandConfig.githubOwnerAndRepo, 'MasoudMaghsodi/MaxGym');
      expect(MaxGymBrandConfig.pwaWebUrl, 'https://maxgym.privatepath.ir');
      expect(MaxGymBrandConfig.latestAndroidApkUrl,
          'https://github.com/MasoudMaghsodi/MaxGym/releases/latest/download/MaxGym-Release.apk');
      expect(MaxGymBrandConfig.superAdminMasterPin, 'MaxGym@Admin2026');
    });

    test('SupabaseCrashTelemetry generates valid device fingerprint',
        () async {
      final devId =
          await SupabaseCrashTelemetry.getOrCreateDeviceFingerprint();
      expect(devId, isNotEmpty);
      expect(devId, startsWith('DEV-'));
    });

    testWidgets('MaxGymDownloadAndPwaHubScreen displays download options & admin gate',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fa'),
          supportedLocales: [
            Locale('fa'),
            Locale('en'),
          ],
          localizationsDelegates: [
            AppStringsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MaxGymDownloadAndPwaHubScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and cards
      expect(find.textContaining('MAX GYM'), findsWidgets);
      expect(find.textContaining('دانلود نسخه اندروید'), findsOneWidget);
      expect(find.textContaining('نسخه ویژه آیفون (iOS PWA)'), findsOneWidget);
      expect(find.textContaining('maxgym.privatepath.ir'), findsWidgets);

      // Tap Super-Admin terminal icon in AppBar
      await tester.tap(find.byIcon(LucideIcons.terminal));
      await tester.pumpAndSettle();

      expect(find.text('ورود به کنسول سوپر-ادمین'), findsOneWidget);

      // Enter Master PIN and unlock
      await tester.enterText(
          find.byType(TextField), MaxGymBrandConfig.superAdminMasterPin);
      await tester.tap(find.text('ورود ادمین'));
      await tester.pumpAndSettle();

      // Should now be on MaxGymSuperAdminScreen
      expect(find.text('👑 کنسول سوپر-ادمین (مدیریت لایسنس و مربیان)'),
          findsOneWidget);
      expect(find.textContaining('Global Kill-Switch'), findsOneWidget);
    });
  });
}
