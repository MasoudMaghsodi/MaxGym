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

class _MockSyncService extends SupabaseSyncService {
  _MockSyncService(super.db);

  @override
  void startAutoSyncListener() {}

  @override
  Future<SyncSummary> syncAllPendingData() async {
    return const SyncSummary(success: true, message: 'Mock Sync');
  }
}

void main() {
  testWidgets(
      'OWASP Security Gate UI Test: Login -> Pending Approval -> Kill-Switch -> Authorized Dashboard',
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
              .overrideWithValue(_MockSyncService(inMemoryDb)),
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

    // ۱. بررسی نمایش صفحه لاگین در حالت غیرلاگین
    expect(find.text('ورود امن مربی به سامانه'), findsOneWidget);

    // ۲. بررسی نمایش صفحه «در انتظار تایید مدیر» (Pending Admin Approval)
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.pendingAdminApproval,
      coachFullName: 'علی رضایی',
      email: 'coach@test.com',
    ));
    await tester.pumpAndSettle();
    expect(find.text('حساب شما در انتظار تایید مدیر است'), findsOneWidget);

    // ۳. بررسی نمایش صفحه قفل کامل اپلیکیشن (Kill-Switch Screen)
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.suspendedKillSwitch,
      lockTitle: 'دسترسی به اپلیکیشن مسدود شده است',
      lockMessage: 'به دلیل عدم تسویه حساب با توسعهدهنده تماس بگیرید.',
      developerContact: '@DeveloperSupport',
    ));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی به اپلیکیشن مسدود شده است'), findsOneWidget);
    expect(find.text('@DeveloperSupport'), findsOneWidget);

    // ۴. ورود به داشبورد اصلی پس از تایید ادمین و تست Privacy Mode و ساخت شاگرد
    gateNotifier.setTestState(const SecurityGateState(
      status: SecurityGateStatus.authorizedAndActive,
      coachFullName: 'علی رضایی',
    ));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد مربی'), findsWidgets);
    await tester.tap(find.byTooltip('مخفی/نمایش مبالغ مالی در حضور شاگرد'));
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsWidgets);

    // ۵. ساخت شاگرد جدید در تب ورزشکاران
    await tester.tap(find.text('ورزشکاران'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('شاگرد جدید +'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'آرش کمانگیر');
    await tester.tap(find.text('ذخیره نهایی'));
    await tester.pumpAndSettle();

    expect(find.textContaining('آرش کمانگیر'), findsOneWidget);
    expect(inMemoryDb.getAllActiveAthletes().length, equals(1));
  });
}
