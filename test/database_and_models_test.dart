import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/database_models.dart';
import 'package:pro_coach_app/data/local/seed_catalog_data.dart';

void main() {
  late LocalAppDatabase db;

  setUp(() {
    db = LocalAppDatabase.initInMemoryForTesting();
  });

  group('Offline Database (SQLite), Custom Catalogs, Billing & Sync Queue Tests', () {
    test('Seeds bilingual catalog and supports Live Search & Custom Coach Moves/Foods/Supps', () {
      // ۱. تست جستجوی زنده حرکات
      final benchSearch = db.getExercisesCatalog(searchQuery: 'پرس سینه');
      expect(benchSearch.isNotEmpty, isTrue);

      // ۲. تست افزودن حرکت سفارشی توسط مربی
      db.addCustomExercise(const ExerciseSeedItem(
        id: 'custom_cable_row_single',
        nameFa: 'زیربغل سیمکش تکدست نشسته',
        nameEn: 'Single-Arm Seated Cable Row',
        targetMuscle: 'back',
        equipment: 'cable',
        imageStartUrl: '',
        imageEndUrl: '',
      ));
      final customSearch = db.getExercisesCatalog(searchQuery: 'تکدست نشسته');
      expect(customSearch.length, equals(1));
      expect(customSearch.first.nameEn, equals('Single-Arm Seated Cable Row'));

      // ۳. تست افزودن غذای سفارشی و مکمل سفارشی توسط مربی
      final initialFoodsCount = db.getFoodsCatalog().length;
      db.addCustomFood(
        nameFa: 'حلیم بوقلمون رژیمی',
        nameEn: 'Lean Turkey Oats Porridge',
        unitFa: '۲۵۰ گرم',
        unitEn: '250g Bowl',
      );
      expect(db.getFoodsCatalog().length, equals(initialFoodsCount + 1));

      final initialSuppsCount = db.getSupplementsCatalog().length;
      db.addCustomSupplement(
        nameFa: 'سیترولین مالات',
        nameEn: 'Citrulline Malate',
        dosageFa: '۶ گرم',
        dosageEn: '6g',
        timingFa: '۳۰ دقیقه قبل تمرین',
        timingEn: '30m Pre-Workout',
      );
      expect(db.getSupplementsCatalog().length, equals(initialSuppsCount + 1));

      // ۴. تست استخراج حرکات سفارشی و تولید فایل بکاپ کامل JSON
      final customOnly = db.getCustomExercisesOnly();
      expect(customOnly.any((e) => e.id == 'custom_cable_row_single'), isTrue);

      final fullJsonBackup = db.exportFullDatabaseToJson();
      expect(fullJsonBackup.contains('custom_cable_row_single'), isTrue);
      expect(fullJsonBackup.contains('Lean Turkey Oats Porridge'), isTrue);
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
      expect(db.getAllActiveAthletes().length, equals(1));
      expect(db.getPendingSyncAthletes().length, equals(1));

      db.markRecordSynced('athletes', 'ath-101');
      expect(db.getPendingSyncAthletes().isEmpty, isTrue);

      db.softDeleteAthlete('ath-101');
      expect(db.getAllActiveAthletes().isEmpty, isTrue);
      expect(db.getPendingSyncAthletes().first.syncStatus, equals('pending_delete'));
    });

    test('Program Superset, Coach Note, Instant Debt Settlement & Template deletion', () {
      final now = DateTime.now();
      final program = FullProgramEntity(
        id: 'prog-debt-1',
        athleteId: 'ath-202',
        title: 'VIP Cut Program',
        startDate: now,
        durationWeeks: 6,
        days: [
          const WorkoutDayPlan(
            dayNumber: 1,
            dayNameFa: 'شنبه',
            dayNameEn: 'Saturday',
            isRestDay: false,
            targetMuscles: ['chest'],
            exercises: [
              WorkoutItemEntity(
                id: 'w-1',
                exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
                exerciseNameFa: 'پرس سینه هالتر',
                exerciseNameEn: 'Barbell Bench Press',
                targetMuscle: 'chest',
                imageStartUrl: '',
                imageEndUrl: '',
                orderIndex: 1,
                setType: SetType.superset,
                supersetGroupId: 'SS_1',
                coachNote: 'مکث ۲ ثانیهای پایین حرکت',
                sets: [
                  SingleSetConfig(setNumber: 1, reps: '8-10', tempo: '3-2-1-0'),
                ],
              ),
            ],
          ),
        ],
        dietMeals: const [],
        supplements: const [],
        totalFee: 1500000,
        paidAmount: 500000, // ۱ میلیون تومان بدهکار
        paymentStatus: 'partial',
        isTemplate: false,
        updatedAt: now,
      );

      db.upsertProgram(program);

      final saved = db.getProgramsForAthlete('ath-202').first;
      expect(saved.remainingDebt, equals(1000000));
      expect(saved.days.first.exercises.first.coachNote,
          equals('مکث ۲ ثانیهای پایین حرکت'));

      // تست دکمه تسویه آنی بدهی مالی (Quick Debt Settlement)
      db.settleProgramDebt('prog-debt-1');
      final settled = db.getProgramsForAthlete('ath-202').first;
      expect(settled.remainingDebt, equals(0));
      expect(settled.paymentStatus, equals('paid'));
      expect(settled.syncStatus, equals('pending_update'));
    });
  });
}
