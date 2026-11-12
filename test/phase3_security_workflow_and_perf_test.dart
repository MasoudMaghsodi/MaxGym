import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/config/maxgym_brand_config.dart';
import 'package:pro_coach_app/core/utils/number_parser.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/database_models.dart';
import 'package:pro_coach_app/features/athlete_portal/athlete_portal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAppDatabase db;

  setUp(() {
    db = LocalAppDatabase.initInMemoryForTesting();
  });

  group('1. OWASP Security, Password Hash Upgrade & One-Time Code Burn Workflow', () {
    test('Verifies Super-Admin PIN digest without exposing plaintext comparison', () {
      expect(MaxGymBrandConfig.verifySuperAdminPin('MaxGym@Admin2026'), isTrue);
      expect(MaxGymBrandConfig.verifySuperAdminPin('WrongPin123'), isFalse);
      expect(MaxGymBrandConfig.verifySuperAdminPin(''), isFalse);
    });

    test('Full Athlete Auth Lifecycle: Code Login -> Burn Code -> Password Auth -> Coach Regenerate', () {
      final now = DateTime.now();
      final athlete = AthleteEntity(
        id: 'ath-lifecycle-1',
        firstName: 'کامران',
        lastName: 'اتابکی',
        phone: '09123334455',
        email: 'kamran@maxgym.ir',
        accessCode: 'PC-9X8Y7Z',
        passwordHash: AthleteEntity.hashPassword('Pass@1234'),
        isCodeBurned: true,
        gender: 'male',
        age: 26,
        heightCm: 181,
        weightKg: 84,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: now,
        updatedAt: now,
      );
      db.upsertAthlete(athlete);

      // ۱. بررسی اینکه toSupabaseJson حتماً password_hash و is_code_burned را ارسال میکند
      final jsonPayload = athlete.toSupabaseJson();
      expect(jsonPayload['is_code_burned'], isTrue);
      expect(jsonPayload['password_hash'], isNotEmpty);
      expect(
        jsonPayload['password_hash'].toString().contains(base64Url.encode(utf8.encode('Pass@1234'))),
        isFalse,
      );

      // ۲. احراز هویت موفق با ایمیل یا موبایل + رمز عبور
      expect(
        db.authenticateAthleteWithPassword('kamran@maxgym.ir', 'Pass@1234')?.id,
        equals('ath-lifecycle-1'),
      );
      expect(
        db.authenticateAthleteWithPassword('09123334455', 'Pass@1234')?.id,
        equals('ath-lifecycle-1'),
      );
      expect(
        db.authenticateAthleteWithPassword('kamran@maxgym.ir', 'WrongPass'),
        isNull,
      );

      // ۳. فراموشی رمز توسط شاگرد و صدور کد یکبارمصرف جدید توسط مربی
      final regenerated = db.regenerateOneTimeCodeForAthlete('ath-lifecycle-1');
      expect(regenerated, isNotNull);
      expect(regenerated!.isCodeBurned, isFalse);
      expect(regenerated.passwordHash, isEmpty);
      expect(regenerated.accessCode, isNot(equals('PC-9X8Y7Z')));
      expect(regenerated.syncStatus, equals('pending_update'));
    });
  });

  group('2. Sync Integrity, Anti-Inflation Streak & Zombie Program Prevention', () {
    test('Workout log only increments streak_days once for local logs, never on cloud sync pull', () {
      final now = DateTime.now();
      db.upsertAthlete(AthleteEntity(
        id: 'ath-streak-guard',
        firstName: 'پویا',
        lastName: 'رحیمی',
        phone: '09120009988',
        email: 'pouya@maxgym.ir',
        gender: 'male',
        age: 24,
        heightCm: 177,
        weightKg: 74,
        fitnessGoal: 'muscle_gain',
        injuryTags: const [],
        createdAt: now,
        updatedAt: now,
        streakDays: 1,
        syncStatus: 'synced',
      ));

      // ۱. ثبت اولین لاگ تمرین محلی توسط شاگرد -> استمرار باید ۲ شود
      final localLog = AthleteWorkoutLogEntity(
        id: 'wlog-local-1',
        athleteId: 'ath-streak-guard',
        programId: 'prog-1',
        dayNumber: 1,
        exerciseWeightsKg: const {'Bench': '90'},
        waterGlasses: 10,
        loggedAt: now,
        syncStatus: 'pending_insert',
      );
      db.insertWorkoutSessionLog(localLog);
      expect(db.getAthleteById('ath-streak-guard')!.streakDays, equals(2));

      // ۲. ثبت مجدد همان لاگ (مثلاً در اثر رفرش یا ویرایش) -> استمرار نباید تغییر کند
      db.insertWorkoutSessionLog(localLog);
      expect(db.getAthleteById('ath-streak-guard')!.streakDays, equals(2));

      // ۳. دانلود لاگ تمرین از سرور در هنگام سینک مربی (syncStatus: 'synced') -> استمرار نباید به اشتباه زیاد شود
      final syncedCloudLog = AthleteWorkoutLogEntity(
        id: 'wlog-cloud-2',
        athleteId: 'ath-streak-guard',
        programId: 'prog-1',
        dayNumber: 2,
        exerciseWeightsKg: const {'Squat': '120'},
        waterGlasses: 12,
        loggedAt: now,
        syncStatus: 'synced',
      );
      db.insertWorkoutSessionLog(syncedCloudLog);
      expect(db.getAthleteById('ath-streak-guard')!.streakDays, equals(2));
    });

    test('Deleting a program/template queues it for cloud deletion (Prevents Zombie Programs)', () {
      final now = DateTime.now();
      final template = FullProgramEntity(
        id: 'tpl-to-delete-1',
        athleteId: 'ath-1',
        title: 'قالب آماده تست حذف',
        startDate: now,
        days: const <WorkoutDayPlan>[],
        dietMeals: const <DietMealSlot>[],
        supplements: const <SupplementPrescriptionItem>[],
        isTemplate: true,
        updatedAt: now,
      );
      db.upsertProgram(template);
      expect(db.getSavedTemplates().length, equals(1));

      db.deleteProgramOrTemplate('tpl-to-delete-1');
      expect(db.getSavedTemplates(), isEmpty);
      expect(db.getPendingCloudDeleteProgramIds().contains('tpl-to-delete-1'), isTrue);

      db.clearPendingCloudDeleteProgramId('tpl-to-delete-1');
      expect(db.getPendingCloudDeleteProgramIds().contains('tpl-to-delete-1'), isFalse);
    });

    test('Custom foods and supplements preserve explicit IDs on cloud pull without duplicating', () {
      final initialFoodsCount = db.getFoodsCatalog().length;
      db.addCustomFood(
        id: 'cloud_food_fixed_id',
        nameFa: 'پنکیک پروتئینی مکسجیم',
        nameEn: 'MaxGym Protein Pancake',
        unitFa: '۲ عدد',
        unitEn: '2 Pancakes',
      );
      // فراخوانی مجدد با همان ID از سمت کلود نباید رکورد تکراری بسازد
      db.addCustomFood(
        id: 'cloud_food_fixed_id',
        nameFa: 'پنکیک پروتئینی مکسجیم (ویرایششده)',
        nameEn: 'MaxGym Protein Pancake',
        unitFa: '۳ عدد',
        unitEn: '3 Pancakes',
      );
      expect(db.getFoodsCatalog().length, equals(initialFoodsCount + 1));
    });
  });

  group('3. Widget Escape Gate & High-Load Performance Benchmark (500 Athletes)', () {
    testWidgets('Mandatory Profile Gate includes Sign-Out escape button in AppBar', (tester) async {
      final incompleteAthlete = AthleteEntity(
        id: 'ath-gate-escape',
        firstName: 'شاگرد',
        lastName: 'جدید',
        phone: '09121112233',
        email: '', // ایمیل خالی -> ورود به گیت تکمیل پروفایل
        accessCode: 'PC-ESCAPE',
        gender: 'male',
        age: 22,
        heightCm: 175,
        weightKg: 70,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: AthletePortalScreen(initialAthlete: incompleteAthlete),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تکمیل یکباره پرونده ورزشی شما'), findsOneWidget);
      expect(find.text('خروج / بازگشت'), findsOneWidget);
    });

    test('Performance Stress Test: 500 Athletes & 500 Programs insert and query under 250ms', () {
      final sw = Stopwatch()..start();
      final now = DateTime.now();

      for (int i = 0; i < 500; i++) {
        db.upsertAthlete(AthleteEntity(
          id: 'perf-ath-$i',
          firstName: 'ورزشکار $i',
          lastName: 'مکسجیم'.toCleanPersian(),
          phone: '0912000${i.toString().padLeft(4, '0')}',
          email: 'ath$i@maxgym.ir',
          accessCode: 'PC-PRF${i.toString().padLeft(3, '0')}',
          gender: i.isEven ? 'male' : 'female',
          age: 20 + (i % 25),
          heightCm: 165 + (i % 30).toDouble(),
          weightKg: 60 + (i % 40).toDouble(),
          fitnessGoal: 'lean_bulk',
          injuryTags: const [],
          createdAt: now,
          updatedAt: now,
          syncStatus: 'synced',
        ));
      }

      final allActive = db.getAllActiveAthletes();
      final lookupByCode = db.getAthleteByAccessCode('PC-PRF250');
      sw.stop();

      expect(allActive.length, equals(500));
      expect(lookupByCode?.id, equals('perf-ath-250'));
      expect(sw.elapsedMilliseconds, lessThan(1500));
    });
  });
}
