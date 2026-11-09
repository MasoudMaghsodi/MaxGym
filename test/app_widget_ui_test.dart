import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/theme/branding_provider.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/remote/supabase_sync_service.dart';
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

class _TestSyncService extends SupabaseSyncService {
  _TestSyncService(super.db);

  @override
  void startAutoSyncListener() {}

  @override
  Future<SyncSummary> syncAllPendingData() async {
    return const SyncSummary(
      syncedAthletes: 0,
      syncedMeasurements: 0,
      syncedPrograms: 0,
      success: true,
      message: 'Test sync skipped',
    );
  }
}

void main() {
  testWidgets(
      'End-to-End UI Suite: Dual Auth, Kill-Switch, Mandatory Athlete Gate, Water Tracker, Chat & Coach Flow',
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
          supabaseSyncServiceProvider
              .overrideWithValue(_TestSyncService(inMemoryDb)),
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

    // ۱. بررسی صفحه ورود دوگانه (مربی / ورزشکار)
    expect(find.text('پنل مربی'), findsOneWidget);
    expect(find.text('پنل ورزشکار'), findsOneWidget);

    // ۲. تست صفحه انتظار تایید مدیر (Pending Admin Approval)
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.pendingAdminApproval,
      coachFullName: 'مربی تست',
      email: 'coach@gym.com',
    ));
    await tester.pumpAndSettle();
    expect(find.text('حساب شما در انتظار تایید مدیر است'), findsOneWidget);

    // ۳. تست صفحه قفل سراسری اپلیکیشن (Kill-Switch Screen)
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.suspendedKillSwitch,
      lockTitle: 'دسترسی به اپلیکیشن مسدود شده است',
      lockMessage: 'لطفاً با توسعهدهنده تماس بگیرید.',
      developerContact: '@SupportAdmin',
    ));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی به اپلیکیشن مسدود شده است'), findsOneWidget);
    expect(find.text('@SupportAdmin'), findsOneWidget);

    // ۴. تست ورود ورزشکار با پروفایل ناقص -> نمایش اجباری گیت تکمیل پرونده
    final incompleteAthlete = AthleteEntity(
      id: 'ath-portal-1',
      firstName: 'سهراب',
      lastName: '',
      phone: '09121112222',
      email: '',
      accessCode: 'PC-777888',
      gender: 'male',
      age: 25,
      heightCm: 180,
      weightKg: 80,
      fitnessGoal: 'lean_bulk',
      injuryTags: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    inMemoryDb.upsertAthlete(incompleteAthlete);

    gateNotifier.setTestState(SecurityGateState(
      status: SecurityGateStatus.athletePortalActive,
      loggedInAthlete: incompleteAthlete,
    ));
    await tester.pumpAndSettle();
    expect(find.text('تکمیل اجباری پرونده ورزشی شما'), findsOneWidget);

    // ۵. تست ورود ورزشکار با پروفایل کامل -> تست کنتور آب و چت متنی با مربی
    final completeAthlete = AthleteEntity(
      id: 'ath-portal-2',
      firstName: 'سهراب',
      lastName: 'سپهری',
      phone: '09121112222',
      email: 'sohrab@gym.com',
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

    expect(find.textContaining('پنل ورزشکار: سهراب سپهری'), findsOneWidget);

    // رفتن به تب تغذیه و آب در پنل ورزشکار و زدن دکمه +۱ لیوان آب
    await tester.tap(find.text('تغذیه، مکمل و آب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+۱ لیوان'));
    await tester.pumpAndSettle();
    expect(find.textContaining('آب مصرفی امروز: 1 از'), findsOneWidget);

    // رفتن به تب گفتگو با مربی و ارسال پیام متنی خالص
    await tester.tap(find.text('گفتگو با مربی'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'سلام استاد تمرین امروز عالی بود');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('سلام استاد تمرین امروز عالی بود'), findsOneWidget);

    // ۶. ورود به پنل مربی تاییدشده و تست ساخت شاگرد جدید
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.authorizedAndActive,
      coachFullName: 'مربی ارشد',
    ));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد مربی'), findsWidgets);
    await tester.tap(find.text('ورزشکاران'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('شاگرد جدید +'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'آرش کمانگیر');
    await tester.tap(find.text('ذخیره نهایی'));
    await tester.pumpAndSettle();

    expect(find.textContaining('آرش کمانگیر'), findsOneWidget);
  });
}
