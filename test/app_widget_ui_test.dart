import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/theme/branding_provider.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'Full UI Test: Dashboard Privacy Mode, Bilingual RTL/LTR, and Athlete Creation',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final inMemoryDb = LocalAppDatabase.initInMemoryForTesting();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const ProCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ۱. بررسی بالا آمدن پیشفرض فارسی (RTL) و تست دکمه مخفیسازی درآمد (Privacy Mode)
    expect(find.text('داشبورد مربی'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(NavigationBar))),
        equals(TextDirection.rtl));

    await tester.tap(find.byTooltip('مخفی/نمایش مبالغ مالی در حضور شاگرد'));
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsWidgets); // مبالغ مالی با موفقیت مخفی شدند

    // ۲. رفتن به تب «ورزشکاران» و ثبت شاگرد جدید
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
