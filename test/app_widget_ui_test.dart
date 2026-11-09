import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/theme/branding_provider.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/remote/supabase_sync_service.dart';
import 'package:pro_coach_app/features/auth/security_gate_screen.dart';
import 'package:pro_coach_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthorizedGateNotifier extends SecurityGateNotifier {
  _MockAuthorizedGateNotifier(super.ref) {
    state = const SecurityGateState(
      status: SecurityGateStatus.authorizedAndActive,
      coachFullName: 'تست مربی',
    );
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
      'OWASP Security Gate & Full UI Test: Kill-Switch, Auth & Dashboard',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final inMemoryDb = LocalAppDatabase.initInMemoryForTesting();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(inMemoryDb),
          supabaseSyncServiceProvider.overrideWithValue(_MockSyncService(inMemoryDb)),
          securityGateProvider
              .overrideWith((ref) => _MockAuthorizedGateNotifier(ref)),
        ],
        child: const ProCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ۱. بررسی بالا آمدن داشبورد پس از عبور از گارد امنیتی و تست Privacy Mode
    expect(find.text('داشبورد مربی'), findsWidgets);
    await tester.tap(find.byTooltip('مخفی/نمایش مبالغ مالی در حضور شاگرد'));
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsWidgets);

    // ۲. تست ساخت ورزشکار جدید
    await tester.tap(find.text('ورزشکاران'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('شاگرد جدید +'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'آرش کمانگیر');
    await tester.tap(find.text('ذخیره نهایی'));
    await tester.pumpAndSettle();

    expect(find.textContaining('آرش کمانگیر'), findsOneWidget);
    expect(inMemoryDb.getAllActiveAthletes().length, equals(1));

    // ۳. تست تغییر آنی زبان به انگلیسی (LTR)
    await tester.tap(find.text('تنظیمات و برندینگ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('زبان اپلیکیشن و خروجی'));
    await tester.pumpAndSettle();

    expect(find.text('Coach Dashboard'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(NavigationBar))),
        equals(TextDirection.ltr));
  });
}
