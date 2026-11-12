import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_coach_app/main.dart' as app;

const _testCoachEmail = String.fromEnvironment(
  'TEST_COACH_EMAIL',
  defaultValue: 'coach_demo@maxgym.ir',
);
const _testCoachPass = String.fromEnvironment(
  'TEST_COACH_PASS',
  defaultValue: 'DemoPass@2026',
);
const _testAthleteCode = String.fromEnvironment(
  'TEST_ATHLETE_CODE',
  defaultValue: 'PC-057537',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Full Android Tour: Coach & Athlete Portal with Comprehensive Screenshots',
      (tester) async {
    Future<void> saveSnap(String filename) async {
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot(filename);
      print('Captured snap: $filename.png');
    }

    app.main();
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await saveSnap('01_security_gate_coach_initial');

    final forgotBtn = find.text('فراموشی رمز عبور؟');
    if (forgotBtn.evaluate().isNotEmpty) {
      await tester.tap(forgotBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      await saveSnap('02_coach_forgot_password_modal');
      await tester.tapAt(const Offset(20, 50));
      await tester.pumpAndSettle();
    }

    final athleteModeBtn = find.text('پنل ورزشکار');
    if (athleteModeBtn.evaluate().isNotEmpty) {
      await tester.tap(athleteModeBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      await saveSnap('03_security_gate_athlete_first_time_tab');

      final passTab = find.textContaining('ورود با رمز عبور');
      if (passTab.evaluate().isNotEmpty) {
        await tester.tap(passTab, warnIfMissed: false);
        await tester.pumpAndSettle();
        await saveSnap('04_security_gate_athlete_password_tab');
      }

      final athForgot = find.textContaining('فراموش کرده‌اید؟');
      if (athForgot.evaluate().isNotEmpty) {
        await tester.tap(athForgot, warnIfMissed: false);
        await tester.pumpAndSettle();
        await saveSnap('05_athlete_forgot_password_modal');
        await tester.tapAt(const Offset(20, 50));
        await tester.pumpAndSettle();
      }

      final coachModeBtn = find.text('پنل مربی');
      if (coachModeBtn.evaluate().isNotEmpty) {
        await tester.tap(coachModeBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }

    final dlHubBtn = find.textContaining('مرکز دانلود اندروید');
    if (dlHubBtn.evaluate().isNotEmpty) {
      await tester.tap(dlHubBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      await saveSnap('06_download_and_pwa_hub');
      final backBtn = find.byType(BackButton);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }

    final textFields = find.byType(TextField);
    if (textFields.evaluate().length >= 2) {
      await tester.enterText(textFields.at(0), _testCoachEmail);
      await tester.enterText(textFields.at(1), _testCoachPass);
      await tester.pumpAndSettle();
      await saveSnap('07_coach_credentials_entered');

      final loginBtn = find.text('ورود به پنل مربی');
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.tap(loginBtn, warnIfMissed: false);
        await Future.delayed(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }
    }

    await saveSnap('08_coach_dashboard_bento');

    final listViews = find.byType(ListView);
    if (listViews.evaluate().isNotEmpty) {
      await tester.drag(listViews.first, const Offset(0, -320));
      await tester.pumpAndSettle();
      await saveSnap('09_coach_dashboard_scrolled');
    }

    final athletesTab = find.text('ورزشکاران');
    if (athletesTab.evaluate().isNotEmpty) {
      await tester.tap(athletesTab, warnIfMissed: false);
      await tester.pumpAndSettle();
      await saveSnap('10_athletes_list');
    }

    final settingsTab = find.text('تنظیمات و برندینگ');
    if (settingsTab.evaluate().isNotEmpty) {
      await tester.tap(settingsTab, warnIfMissed: false);
      await tester.pumpAndSettle();
      await saveSnap('18_settings_and_branding');

      final signOutBtn = find.byTooltip('خروج امن از حساب');
      if (signOutBtn.evaluate().isNotEmpty) {
        await tester.tap(signOutBtn, warnIfMissed: false);
        await Future.delayed(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }
    }

    final athleteModeBtn2 = find.text('پنل ورزشکار');
    if (athleteModeBtn2.evaluate().isNotEmpty) {
      await tester.tap(athleteModeBtn2, warnIfMissed: false);
      await tester.pumpAndSettle();

      final codeField = find.byType(TextField).first;
      await tester.enterText(codeField, _testAthleteCode);
      await tester.pumpAndSettle();
      await saveSnap('19_athlete_code_entered');

      final viewProgBtn = find.text('مشاهده برنامه تمرینی و چت با مربی');
      if (viewProgBtn.evaluate().isNotEmpty) {
        await tester.tap(viewProgBtn, warnIfMissed: false);
        await Future.delayed(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }
    }

    final nutritionNav = find.byIcon(LucideIcons.apple);
    if (nutritionNav.evaluate().isNotEmpty) {
      await tester.tap(nutritionNav, warnIfMissed: false);
      await tester.pumpAndSettle();
      await saveSnap('24_athlete_portal_nutrition_vertical_pillars');
    }
  });
}
