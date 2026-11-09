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
      'Dual-Portal UI Test: Coach Auth, Kill-Switch, Mandatory Athlete Profile Gate & Athlete Portal',
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

    // ۲. شبیهسازی ورود ورزشکاری که پروفایلش ناقص است (ایمیل ندارد) -> باید گیت تکمیل پروفایل باز شود
    final incompleteAthlete = AthleteEntity(
      id: 'ath-portal-1',
      firstName: 'سهراب',
      lastName: '', // نام خانوادگی خالی
      phone: '09121112222',
      email: '', // ایمیل خالی
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

    // بررسی باز شدن صفحه «تکمیل اجباری پرونده ورزشی شما»
    expect(find.text('تکمیل اجباری پرونده ورزشی شما'), findsOneWidget);

    // ۳. شبیهسازی ورود ورزشکاری که پروفایلش کامل است -> باید مستقیم وارد داشبورد ورزشکار و چت شود
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
    expect(find.text('گفتگو با مربی'), findsOneWidget);

    // ۴. بازگشت به پنل مربی تاییدشده
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.authorizedAndActive,
      coachFullName: 'مربی ارشد',
    ));
    await tester.pumpAndSettle();
    expect(find.text('داشبورد مربی'), findsWidgets);
  });
}
