import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/database_models.dart';
import 'package:pro_coach_app/data/local/seed_catalog_data.dart';

void main() {
  late LocalAppDatabase db;

  setUp(() {
    db = LocalAppDatabase.initInMemoryForTesting();
  });

  group('Offline Database (SQLite), Custom Catalogs, Billing & OWASP Wipe Tests', () {
    test('Supports Live Search & Custom Coach Moves, Foods, and Supplements', () {
      expect(db.getExercisesCatalog(searchQuery: 'پرس سینه').isNotEmpty, isTrue);

      db.addCustomExercise(const ExerciseSeedItem(
        id: 'custom_cable_row_single',
        nameFa: 'زیربغل سیمکش تکدست نشسته',
        nameEn: 'Single-Arm Seated Cable Row',
        targetMuscle: 'back',
        equipment: 'custom',
        imageStartUrl: '',
        imageEndUrl: '',
      ));
      expect(db.getCustomExercisesOnly().length, equals(1));

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
    });

    test('Program Superset, Coach Note, Debt Settlement & JSON Backup work cleanly', () {
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
        paidAmount: 500000,
        paymentStatus: 'partial',
        isTemplate: false,
        updatedAt: now,
      );

      db.upsertProgram(program);
      expect(db.getProgramsForAthlete('ath-202').first.remainingDebt, equals(1000000));

      // تسویه بدهی
      db.settleProgramDebt('prog-debt-1');
      expect(db.getProgramsForAthlete('ath-202').first.remainingDebt, equals(0));

      // تست خروجی بکاپ JSON
      final backupJson = db.exportFullDatabaseToJson();
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
      expect((decoded['athletes'] as List).length, equals(1));
      expect((decoded['programs'] as List).length, equals(1));

      // تست پاکسازی امنیتی OWASP M9 هنگام خروج از حساب
      db.clearAllUserDataOnLogout();
      expect(db.getAllActiveAthletes().isEmpty, isTrue);
      expect(db.getAllPrograms(includeTemplates: true).isEmpty, isTrue);
    });
  });
}
