import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pro_coach_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full iOS Simulator Tour: Coach & Athlete PC-057537 with Screenshots',
      (tester) async {
    const iosDir = '/Users/a1/Downloads/MaxGym/screenshots/ios';
    Directory(iosDir).createSync(recursive: true);

    Future<void> saveSnap(String filename) async {
      await tester.pump(const Duration(milliseconds: 300));
      try {
        final bytes = await binding.takeScreenshot(filename);
        File('$iosDir/$filename.png').writeAsBytesSync(bytes);
        print('Captured iOS snap: $filename.png');
      } catch (e) {
        // Fallback to xcrun simctl screenshot
        Process.runSync('xcrun', [
          'simctl',
          'io',
          '6BB28433-8C12-471A-98B5-F5C0EEDBF25A',
          'screenshot',
          '$iosDir/$filename.png',
        ]);
        print('Captured via xcrun simctl: $filename.png');
      }
    }

    // 1. Launch App
    app.main();
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await saveSnap('01_ios_security_gate_coach');

    // 2. Coach Login
    final textFields = find.byType(TextField);
    if (textFields.evaluate().length >= 2) {
      await tester.enterText(textFields.at(0), 'magsodi333@gmail.com');
      await tester.enterText(textFields.at(1), 'm.m.80112100');
      await tester.pumpAndSettle();
      await saveSnap('02_ios_coach_credentials_entered');

      final loginBtn = find.text('ورود به پنل مربی');
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.tap(loginBtn);
        await Future.delayed(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }
    }

    // 3. Coach Dashboard Bento Grid
    await saveSnap('03_ios_coach_dashboard_bento');

    // Scroll dashboard
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    await saveSnap('04_ios_coach_dashboard_scrolled');

    // 4. Athletes Tab
    final athletesTab = find.text('ورزشکاران');
    if (athletesTab.evaluate().isNotEmpty) {
      await tester.tap(athletesTab);
      await tester.pumpAndSettle();
      await saveSnap('05_ios_athletes_list_glass');

      // 1RM Calculator
      final calcIcon = find.byIcon(Icons.calculate);
      final calcFallback = find.byTooltip('ماشینحساب 1RM');
      if (calcFallback.evaluate().isNotEmpty) {
        await tester.tap(calcFallback);
        await tester.pumpAndSettle();
        await saveSnap('06_ios_1rm_calculator');
        final closeBtn = find.text('بستن');
        if (closeBtn.evaluate().isNotEmpty) {
          await tester.tap(closeBtn);
          await tester.pumpAndSettle();
        }
      }

      // Open Athlete Detail
      final athleteCard = find.textContaining('مسعود مقصودی');
      if (athleteCard.evaluate().isNotEmpty) {
        await tester.tap(athleteCard.first);
        await tester.pumpAndSettle();
        await saveSnap('07_ios_athlete_detail_macro_rings');

        // Scroll Detail
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();
        await saveSnap('08_ios_athlete_detail_bio_gauges');

        // Progress Charts Tab
        final chartsTab = find.text('نمودار سایزها');
        if (chartsTab.evaluate().isNotEmpty) {
          await tester.tap(chartsTab);
          await tester.pumpAndSettle();
          await saveSnap('09_ios_athlete_charts_and_radar');
        }

        // Programs Tab
        final progsTab = find.textContaining('برنامهها');
        if (progsTab.evaluate().isNotEmpty) {
          await tester.tap(progsTab);
          await tester.pumpAndSettle();
          await saveSnap('10_ios_athlete_programs_pdf');
        }

        // Back to list
        final backBtn = find.byType(BackButton);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn);
          await tester.pumpAndSettle();
        }
      }
    }

    // 5. Settings Tab & Sign Out
    final settingsTab = find.text('تنظیمات و برندینگ');
    if (settingsTab.evaluate().isNotEmpty) {
      await tester.tap(settingsTab);
      await tester.pumpAndSettle();
      await saveSnap('11_ios_settings_branding');

      final signOutBtn = find.byTooltip('خروج امن از حساب');
      if (signOutBtn.evaluate().isNotEmpty) {
        await tester.tap(signOutBtn);
        await Future.delayed(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }
    }

    // 6. Athlete Portal Login with PC-057537
    final athleteModeBtn = find.text('پنل ورزشکار');
    if (athleteModeBtn.evaluate().isNotEmpty) {
      await tester.tap(athleteModeBtn);
      await tester.pumpAndSettle();
      await saveSnap('12_ios_security_gate_athlete_tab');

      final codeField = find.byType(TextField).first;
      await tester.enterText(codeField, 'PC-057537');
      await tester.pumpAndSettle();
      await saveSnap('13_ios_athlete_code_entered');

      final viewProgBtn = find.text('مشاهده برنامه تمرینی و چت با مربی');
      if (viewProgBtn.evaluate().isNotEmpty) {
        await tester.tap(viewProgBtn);
        await Future.delayed(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }
    }

    // 7. Athlete Portal Tabs
    await saveSnap('14_ios_athlete_portal_workout_front');

    final rotate3d = find.text('چرخش 3D بدن');
    if (rotate3d.evaluate().isNotEmpty) {
      await tester.tap(rotate3d);
      await tester.pumpAndSettle();
      await saveSnap('15_ios_athlete_portal_workout_back');
    }

    final nutritionTab = find.text('تغذیه و مکمل');
    if (nutritionTab.evaluate().isNotEmpty) {
      await tester.tap(nutritionTab);
      await tester.pumpAndSettle();
      await saveSnap('16_ios_athlete_diet_and_supplements');

      final plusWater = find.text('+۱ لیوان');
      if (plusWater.evaluate().isNotEmpty) {
        await tester.tap(plusWater);
        await tester.pumpAndSettle();
        await saveSnap('17_ios_athlete_hydration_updated');
      }
    }

    final chatTab = find.text('چت زنده مربی');
    if (chatTab.evaluate().isNotEmpty) {
      await tester.tap(chatTab);
      await tester.pumpAndSettle();
      await saveSnap('18_ios_athlete_realtime_chat');
    }

    print('iOS Simulator full tour completed successfully!');
  });
}
