import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/theme/branding_provider.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'Full UI Smoke Test: Navigation, Bilingual RTL/LTR Switching, and Athlete Onboarding Modal',
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

    // ۱. بررسی بالا آمدن پیشفرض به زبان فارسی و راستچین (RTL)
    expect(find.text('داشبورد مربی'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(NavigationBar))),
        equals(TextDirection.rtl));

    // ۲. رفتن به تب «ورزشکاران» و باز کردن فرم ۲ مرحله‌ای شاگرد جدید
    await tester.tap(find.text('ورزشکاران'));
    await tester.pumpAndSettle();

    expect(find.text('شاگرد جدید +'), findsOneWidget);
    await tester.tap(find.text('شاگرد جدید +'));
    await tester.pumpAndSettle();

    // بررسی باز شدن BottomSheet گام ۱
    expect(find.textContaining('گام ۱: مشخصات پایه'), findsOneWidget);

    // وارد کردن نام ورزشکار و ذخیره سریع
    final nameField = find.byType(TextField).at(1);
    await tester.enterText(nameField, 'آرش کمانگیر');
    await tester.tap(find.text('ذخیره نهایی'));
    await tester.pumpAndSettle();

    // بررسی اضافه شدن ورزشکار به لیست و دیتابیس
    expect(find.textContaining('آرش کمانگیر'), findsOneWidget);
    expect(inMemoryDb.getAllActiveAthletes().length, equals(1));

    // ۳. رفتن به تب تنظیمات و تست تغییر آنی زبان به انگلیسی (LTR)
    await tester.tap(find.text('تنظیمات و برندینگ'));
    await tester.pumpAndSettle();

    // کلیک روی آیکون تغییر زبان در AppBar
    await tester.tap(find.byTooltip('زبان اپلیکیشن و خروجی'));
    await tester.pumpAndSettle();

    // اکنون کل رابط کاربری باید انگلیسی و چپ‌چین (LTR) شده باشد
    expect(find.text('Coach Dashboard'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(NavigationBar))),
        equals(TextDirection.ltr));
  });
}
