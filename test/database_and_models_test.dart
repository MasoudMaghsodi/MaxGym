import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/database_models.dart';
import 'package:pro_coach_app/data/local/seed_catalog_data.dart';

void main() {
  late LocalAppDatabase db;

  setUp(() {
    db = LocalAppDatabase.initInMemoryForTesting();
  });

  group('Offline Database (SQLite) & Outbox Sync Queue Tests', () {
    test('Seeds bilingual exercise catalog automatically on init', () {
      final allExercises = db.getExercisesCatalog();
      expect(allExercises.isNotEmpty, isTrue);

      final chestMoves = db.getExercisesCatalog(muscleFilter: 'chest');
      expect(chestMoves.every((m) => m.targetMuscle == 'chest'), isTrue);
      expect(chestMoves.first.nameFa.isNotEmpty, isTrue);
      expect(chestMoves.first.nameEn.isNotEmpty, isTrue);
    });

    test('Athlete CRUD & Soft Delete updates Outbox Sync Queue status', () {
      final now = DateTime.now();
      final athlete = AthleteEntity(
        id: 'ath-101',
        firstName: 'محمد',
        lastName: 'کریمی',
        phone: '09121112233',
        gender: 'male',
        age: 24,
        heightCm: 178,
        weightKg: 76,
        fitnessGoal: 'muscle_gain',
        injuryTags: const ['lower_back'],
        createdAt: now,
        updatedAt: now,
      );

      db.upsertAthlete(athlete);

      // باید در لیست فعال و همچنین در صف انتظار سینک (Pending Sync) قرار بگیرد
      expect(db.getAllActiveAthletes().length, equals(1));
      expect(db.getPendingSyncAthletes().length, equals(1));

      // شبیه‌سازی سینک موفق با Supabase
      db.markRecordSynced('athletes', 'ath-101');
      expect(db.getPendingSyncAthletes().isEmpty, isTrue);

      // حذف نرم (Soft Delete)
      db.softDeleteAthlete('ath-101');
      expect(db.getAllActiveAthletes().isEmpty, isTrue);
      // رکورد حذف‌شده باید مجدداً وارد صف سینک شود تا در Supabase هم حذف شود
      expect(db.getPendingSyncAthletes().first.syncStatus, equals('pending_delete'));
    });

    test('Measurement Log updates Athlete current weight automatically', () {
      final now = DateTime.now();
      db.upsertAthlete(AthleteEntity(
        id: 'ath-202',
        firstName: 'Sina',
        lastName: 'Moradi',
        phone: '09123334455',
        gender: 'male',
        age: 29,
        heightCm: 182,
        weightKg: 80.0,
        fitnessGoal: 'weight_loss',
        injuryTags: const [],
        createdAt: now,
        updatedAt: now,
      ));

      // ثبت سایزگیری جدید با وزن 77.5 کیلوگرم
      db.insertMeasurementLog(MeasurementLogEntity(
        id: 'log-1',
        athleteId: 'ath-202',
        recordedAt: now,
        weightKg: 77.5,
        waistCm: 82.0,
        bicepsCm: 40.5,
        updatedAt: now,
      ));

      final updatedAthlete = db.getAthleteById('ath-202')!;
      expect(updatedAthlete.weightKg, equals(77.5));
      expect(db.getMeasurementsForAthlete('ath-202').length, equals(1));
    });

    test('Superset grouping, Diet OR-Alternatives, and Templates serialize cleanly', () {
      final now = DateTime.now();
      final program = FullProgramEntity(
        id: 'prog-1',
        athleteId: 'ath-202',
        title: 'Pro Hypertrophy Phase 1',
        startDate: now,
        durationWeeks: 6,
        days: [
          WorkoutDayPlan(
            dayNumber: 1,
            dayNameFa: 'شنبه',
            dayNameEn: 'Saturday',
            isRestDay: false,
            targetMuscles: const ['biceps', 'triceps'],
            exercises: const [
              WorkoutItemEntity(
                id: 'w-1',
                exerciseId: 'Barbell_Curl',
                exerciseNameFa: 'جلوبازو هالتر',
                exerciseNameEn: 'Barbell Curl',
                targetMuscle: 'biceps',
                imageStartUrl: 'url1',
                imageEndUrl: 'url2',
                orderIndex: 1,
                setType: SetType.superset,
                supersetGroupId: 'SS_ARM_1',
                sets: [
                  SingleSetConfig(setNumber: 1, reps: '10-12', tempo: '3-1-1-0'),
                ],
              ),
              WorkoutItemEntity(
                id: 'w-2',
                exerciseId: 'Triceps_Pushdown',
                exerciseNameFa: 'پشتبازو سیمکش',
                exerciseNameEn: 'Triceps Pushdown',
                targetMuscle: 'triceps',
                imageStartUrl: 'url3',
                imageEndUrl: 'url4',
                orderIndex: 2,
                setType: SetType.superset,
                supersetGroupId: 'SS_ARM_1',
                sets: [
                  SingleSetConfig(
                      setNumber: 1, reps: '12-15', isDropSet: true),
                ],
              ),
            ],
          ),
        ],
        dietMeals: const [
          DietMealSlot(
            slotId: 'lunch',
            titleFa: 'ناهار',
            titleEn: 'Lunch',
            items: [
              MealFoodRow(
                foodNameFa: 'سینه مرغ',
                foodNameEn: 'Chicken Breast',
                amountFa: '۱۵۰ گرم',
                amountEn: '150g',
                alternativesFa: ['۱۵۰ گرم ماهی سفید', '۵ سفیده تخم‌مرغ'],
                alternativesEn: ['150g White Fish', '5 Egg Whites'],
              ),
            ],
          ),
        ],
        supplements: const [
          SupplementPrescriptionItem(
            supplementId: 'creatine',
            nameFa: 'کراتین',
            nameEn: 'Creatine',
            dosageFa: '۵ گرم',
            dosageEn: '5g',
            timingFa: 'بعد از تمرین',
            timingEn: 'Post-Workout',
            onlyTrainingDays: true,
          ),
        ],
        totalFee: 1200000,
        paidAmount: 800000,
        paymentStatus: 'partial',
        isTemplate: false,
        updatedAt: now,
      );

      db.upsertProgram(program);

      final loaded = db.getProgramsForAthlete('ath-202').first;
      expect(loaded.remainingDebt, equals(400000));
      expect(loaded.days.first.exercises[0].supersetGroupId, equals('SS_ARM_1'));
      expect(loaded.days.first.exercises[1].supersetGroupId, equals('SS_ARM_1'));
      expect(loaded.days.first.exercises[1].sets.first.isDropSet, isTrue);
      expect(loaded.dietMeals.first.items.first.alternativesFa.length, equals(2));
      expect(loaded.supplements.first.onlyTrainingDays, isTrue);
    });

    test('Custom Coach Catalog (Moves, Foods, Supps) and Search Queries', () {
      // ۱. افزودن حرکت سفارشی مربی و جستجوی آن
      db.addCustomExercise(
        const ExerciseSeedItem(
          id: 'custom_incline_fly',
          nameFa: 'بالاسینه دمبل موازی مربی',
          nameEn: 'Coach Custom Incline Dumbbell Fly',
          targetMuscle: 'chest',
          equipment: 'dumbbell',
          imageStartUrl: 'url_start',
          imageEndUrl: 'url_end',
        ),
      );

      final searchResults = db.getExercisesCatalog(searchQuery: 'موازی مربی');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.nameEn, contains('Coach Custom'));

      // ۲. افزودن غذای سفارشی مربی به بانک غذا
      db.addCustomFood(
        nameFa: 'حلیم گوشت بوقلمون',
        nameEn: 'Turkey Haleem',
        unitFa: '۲۵۰ گرم',
        unitEn: '250g',
      );

      final foods = db.getFoodsCatalog();
      expect(foods.any((f) => f['nameFa'] == 'حلیم گوشت بوقلمون'), isTrue);

      // ۳. افزودن مکمل سفارشی
      db.addCustomSupplement(
        nameFa: 'سیترولین مالات',
        nameEn: 'Citrulline Malate',
        dosageFa: '۶ گرم',
        dosageEn: '6g',
        timingFa: '۳۰ دقیقه قبل تمرین',
        timingEn: '30m Pre-Workout',
      );

      final supps = db.getSupplementsCatalog();
      expect(supps.any((s) => s['nameFa'] == 'سیترولین مالات'), isTrue);
    });

    test('Quick Debt Settlement and Template Deletion', () {
      final now = DateTime.now();
      const programId = 'prog_debt_test';
      final program = FullProgramEntity(
        id: programId,
        athleteId: 'ath-202',
        title: 'برنامه تست بدهی',
        startDate: now,
        durationWeeks: 4,
        days: const [],
        dietMeals: const [],
        waterLiters: 3.0,
        dietGuidelines: const [],
        supplements: const [],
        totalFee: 1500000,
        paidAmount: 500000,
        paymentStatus: 'partial',
        isTemplate: false,
        updatedAt: now,
      );

      final template = FullProgramEntity(
        id: 'tpl_1',
        athleteId: 'ath-202',
        title: 'قالب تست جهت حذف',
        startDate: now,
        durationWeeks: 4,
        days: const [],
        dietMeals: const [],
        waterLiters: 3.0,
        dietGuidelines: const [],
        supplements: const [],
        totalFee: 1000000,
        paidAmount: 1000000,
        paymentStatus: 'paid',
        isTemplate: true,
        updatedAt: now,
      );

      db.upsertProgram(program);
      db.upsertProgram(template);
      expect(db.getSavedTemplates().length, equals(1));

      // تسویه آنی بدهی
      db.settleProgramDebt(programId);
      final updatedProg = db.getProgramsForAthlete('ath-202').first;
      expect(updatedProg.remainingDebt, equals(0));
      expect(updatedProg.paymentStatus, equals('paid'));
      expect(updatedProg.paidAmount, equals(1500000));

      // حذف قالب آماده
      db.deleteProgramOrTemplate('tpl_1');
      expect(db.getSavedTemplates().isEmpty, isTrue);
    });
  });
}
