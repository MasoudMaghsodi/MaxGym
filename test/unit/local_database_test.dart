import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';

void main() {
  late LocalAppDatabase db;

  setUp(() {
    db = LocalAppDatabase.inMemory();
  });

  tearDown(() {
    db.close();
  });

  group('LocalAppDatabase In-Memory Tests', () {
    test('Can upsert, get and list athletes', () {
      final now = DateTime.now();
      final athlete = AthleteEntity(
        id: 'test-uuid-1',
        firstName: 'Ali',
        lastName: 'Rezaei',
        phone: '09121112233',
        gender: 'male',
        age: 26,
        heightCm: 182,
        weightKg: 80,
        fitnessGoal: 'muscle_gain',
        injuryTags: ['lower_back'],
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending_insert',
      );

      db.upsertAthlete(athlete);

      final retrieved = db.getAthleteById('test-uuid-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.fullName, 'Ali Rezaei');
      expect(retrieved.injuryTags, contains('lower_back'));

      final all = db.getAllActiveAthletes();
      expect(all.length, 1);
    });

    test('Can save full program and retrieve templates', () {
      final now = DateTime.now();
      final program = FullProgramEntity(
        id: 'prog-uuid-1',
        athleteId: 'test-uuid-1',
        title: 'قالب تست ۴ روزه',
        startDate: now,
        durationWeeks: 4,
        days: [
          const WorkoutDayPlan(
            dayNumber: 1,
            dayNameFa: 'شنبه',
            dayNameEn: 'Saturday',
            targetMuscles: ['سینه', 'پشت بازو'],
            isRestDay: false,
            exercises: [],
          ),
        ],
        dietMeals: [],
        waterLiters: 3.5,
        dietGuidelines: ['قند و شیرینی مصرف نشود'],
        supplements: [],
        totalFee: 2500000,
        paidAmount: 2500000,
        paymentStatus: 'paid',
        isTemplate: true,
        updatedAt: now,
      );

      db.upsertProgram(program);

      final templates = db.getSavedTemplates();
      expect(templates.length, 1);
      expect(templates.first.title, 'قالب تست ۴ روزه');
      expect(templates.first.isTemplate, isTrue);
    });
  });
}
