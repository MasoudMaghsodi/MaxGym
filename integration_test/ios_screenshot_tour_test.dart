import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

  testWidgets('Full iOS Simulator Tour: Coach & Athlete Portal with Screenshots',
      (tester) async {
    const iosDir = 'screenshots/ios';
    Directory(iosDir).createSync(recursive: true);

    Future<void> saveSnap(String filename) async {
      await tester.pump(const Duration(milliseconds: 300));
      try {
        final bytes = await binding.takeScreenshot(filename);
        File('$iosDir/$filename.png').writeAsBytesSync(bytes);
      } catch (_) {}
    }

    app.main();
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await saveSnap('01_ios_security_gate_coach');

    final textFields = find.byType(TextField);
    if (textFields.evaluate().length >= 2) {
      await tester.enterText(textFields.at(0), _testCoachEmail);
      await tester.enterText(textFields.at(1), _testCoachPass);
      await tester.pumpAndSettle();
      await saveSnap('02_ios_coach_credentials_entered');

      final loginBtn = find.text('ورود به پنل مربی');
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.tap(loginBtn);
        await Future.delayed(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }
    }

    await saveSnap('03_ios_coach_dashboard_bento');

    final athleteModeBtn = find.text('پنل ورزشکار');
    if (athleteModeBtn.evaluate().isNotEmpty) {
      await tester.tap(athleteModeBtn);
      await tester.pumpAndSettle();

      final codeField = find.byType(TextField).first;
      await tester.enterText(codeField, _testAthleteCode);
      await tester.pumpAndSettle();
      await saveSnap('13_ios_athlete_code_entered');
    }
  });
}
