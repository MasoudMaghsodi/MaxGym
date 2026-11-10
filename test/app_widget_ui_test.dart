import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/theme/branding_provider.dart';
import 'package:pro_coach_app/core/widgets/maxgym_3d_widgets.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/features/admin_and_download/maxgym_hub_and_admin_screen.dart';
import 'package:pro_coach_app/features/auth/security_gate_screen.dart';
import 'package:pro_coach_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSecurityGateNotifier extends SecurityGateNotifier {
  _TestSecurityGateNotifier(super.ref, SecurityGateState initial) {
    state = initial;
  }

  void setTestState(SecurityGateState newState) {
    state = newState;
  }

  @override
  Future<void> verifySecurityAndSession() async {}
}

void main() {
  testWidgets(
      'MaxGym Ultimate UI Suite: Dual Auth, Kill-Switch, Athlete Portal, 3D Heatmap & Download Hub',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final inMemoryDb = LocalAppDatabase.initInMemoryForTesting();

    late _TestSecurityGateNotifier gateNotifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(inMemoryDb),
          securityGateProvider.overrideWith((ref) {
            gateNotifier = _TestSecurityGateNotifier(
              ref,
              const SecurityGateState(
                  status: SecurityGateStatus.unauthenticated),
            );
            return gateNotifier;
          }),
        ],
        child: const ProCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ۱. بررسی صفحه ورود دوگانه (پنل مربی / پنل ورزشکار)
    expect(find.text('پنل مربی'), findsOneWidget);
    expect(find.text('پنل ورزشکار'), findsOneWidget);

    // ۲. تست صفحه قفل سراسری اپلیکیشن (Kill-Switch Screen)
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.suspendedKillSwitch,
      lockTitle: 'دسترسی به اپلیکیشن مسدود شده است',
      lockMessage: 'لطفاً با توسعه‌دهنده تماس بگیرید.',
      developerContact: '@SupportAdmin',
    ));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی به اپلیکیشن مسدود شده است'), findsOneWidget);

    // ۳. تست ورود ورزشکار با پروفایل کامل -> کنتور آب و چت زنده
    final completeAthlete = AthleteEntity(
      id: 'ath-portal-2',
      firstName: 'سهراب',
      lastName: 'سپهری',
      phone: '09121112222',
      email: 'sohrab@maxgym.ir',
      accessCode: 'PC-999000',
      gender: 'male',
      age: 25,
      heightCm: 180,
      weightKg: 80,
      fitnessGoal: 'lean_bulk',
      injuryTags: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    inMemoryDb.upsertAthlete(completeAthlete);

    gateNotifier.setTestState(SecurityGateState(
      status: SecurityGateStatus.athletePortalActive,
      loggedInAthlete: completeAthlete,
    ));
    await tester.pumpAndSettle();

    expect(find.text('سهراب سپهری'), findsOneWidget);

    await tester.tap(find.text('تغذیه و مکمل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+۱ لیوان'));
    await tester.pumpAndSettle();
    expect(find.textContaining('آبرسانی بدن: 1 از'), findsOneWidget);

    // ۴. تست ویجت هیت‌مپ سه‌بعدی عضلات بدن و مرکز دانلود MaxGym
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Interactive3DMuscleAnatomy(
            activeMuscles: ['chest', 'biceps'],
            isFa: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('هیت‌مپ سه‌بعدی آناتومی عضلات'), findsOneWidget);
    await tester.tap(find.text('چرخش 3D بدن'));
    await tester.pumpAndSettle();
    expect(find.textContaining('نمای پشت'), findsOneWidget);

    // ۵. تست صفحه مرکز دانلود و راهنمای PWA آیفون
    await tester.pumpWidget(
      const MaterialApp(
        home: MaxGymDownloadAndPwaHubScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('maxgym.privatepath.ir'), findsWidgets);
  });
}
