import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/database_models.dart';
import 'package:pro_coach_app/data/local/seed_catalog_data.dart';

void main() {
  late LocalAppDatabase db;

  setUp(() {
    db = LocalAppDatabase.initInMemoryForTesting();
  });

  group('Offline SQLite Engine, Rich Catalogs, Workout Logs & Security Tests', () {
    test('Seeds expanded exercises, Persian foods, and 35+ supplements/vitamins', () {
      expect(db.getExercisesCatalog().length, greaterThanOrEqualTo(45));
      expect(db.getFoodsCatalog().length, greaterThanOrEqualTo(30));
      expect(db.getSupplementsCatalog().length, greaterThanOrEqualTo(35));

      final imported = db.importGlobal800ExercisesBatch([
        {
          'id': 'Global_Move_1',
          'name': 'Seated Cable Row',
          'primaryMuscles': ['lats'],
          'equipment': 'cable',
          'images': ['Seated_Cable_Rows/0.jpg', 'Seated_Cable_Rows/1.jpg'],
        }
      ]);
      expect(imported, equals(1));
      expect(db.getExercisesCatalog(searchQuery: 'Global_Move_1').isNotEmpty, isTrue);
    });

    test('Supports Custom Coach Exercises, Custom Foods, and Custom Supplements', () {
      db.addCustomExercise(const ExerciseSeedItem(
        id: 'custom_move_99',
        nameFa: 'حرکت اختصاصی مکس‌جیم',
        nameEn: 'MaxGym Special Press',
        targetMuscle: 'chest',
        equipment: 'custom',
        imageStartUrl: '',
        imageEndUrl: '',
      ));
      expect(db.getCustomExercisesOnly().length, equals(1));

      final fCount = db.getFoodsCatalog().length;
      db.addCustomFood(
        nameFa: 'پروتئین بار مکس‌جیم',
        nameEn: 'MaxGym Protein Bar',
        unitFa: '۱ عدد (۶۰ گرم)',
        unitEn: '1 Bar (60g)',
      );
      expect(db.getFoodsCatalog().length, equals(fCount + 1));
    });

    test('Athlete Access Code, Auto-Draft, Pure Text Chat & Workout Logs work end-to-end', () {
      final now = DateTime.now();
      final athlete = AthleteEntity(
        id: 'ath-500',
        firstName: 'کیوان',
        lastName: 'نوری',
        phone: '09121234567',
        email: '',
        gender: 'male',
        age: 27,
        heightCm: 180,
        weightKg: 82,
        fitnessGoal: 'lean_bulk',
        injuryTags: const ['shoulder'],
        createdAt: now,
        updatedAt: now,
      );

      db.upsertAthlete(athlete);
      final savedAth = db.getAthleteById('ath-500')!;
      expect(savedAth.accessCode, startsWith('PC-'));
      expect(savedAth.isProfileComplete, isFalse);

      expect(db.getAthleteByAccessCode(savedAth.accessCode)?.id, equals('ath-500'));

      final draft = FullProgramEntity(
        id: 'draft-1',
        athleteId: 'ath-500',
        title: 'پیش‌نویس نیمه‌کاره',
        startDate: now,
        days: const <WorkoutDayPlan>[],
        dietMeals: const <DietMealSlot>[],
        supplements: const <SupplementPrescriptionItem>[],
        updatedAt: now,
      );
      db.saveProgramDraft('ath-500', draft);
      expect(db.getProgramDraft('ath-500')?.title, equals('پیش‌نویس نیمه‌کاره'));
      db.clearProgramDraft('ath-500');
      expect(db.getProgramDraft('ath-500'), isNull);

      db.insertChatMessage(ChatMessageEntity(
        id: 'msg-1',
        athleteId: 'ath-500',
        senderRole: 'athlete',
        messageText: 'سلام استاد، امروز وزنه پرس سینه رو ۵ کیلو اضافه کردم!',
        createdAt: now,
      ));
      expect(db.getChatMessagesForAthlete('ath-500').length, equals(1));
      db.markRecordSynced('chat_messages', 'msg-1');
      expect(db.getPendingSyncChatMessages().isEmpty, isTrue);

      db.upsertWorkoutLog(AthleteWorkoutLogEntity(
        id: 'wlog-1',
        athleteId: 'ath-500',
        programId: 'prog-1',
        dayNumber: 1,
        exerciseWeightsKg: const {'Barbell_Bench_Press': '85'},
        waterGlasses: 12,
        sessionRpe: 9,
        athleteFeedback: 'عالی بود',
        loggedAt: now,
      ));
      final wLogs = db.getWorkoutLogsForAthlete('ath-500');
      expect(wLogs.length, equals(1));
      expect(wLogs.first.waterGlasses, equals(12));
    });

    test('Prevents SQL Injection on table name in markRecordSynced (Whitelist Guard)', () {
      expect(
        () => db.markRecordSynced('athletes; DROP TABLE athletes; --', 'id-1'),
        throwsArgumentError,
      );
    });

    test('Exports full database to JSON, wipes on logout, and restores cleanly', () {
      final now = DateTime.now();
      db.upsertAthlete(AthleteEntity(
        id: 'ath-restore-1',
        firstName: 'امیر',
        lastName: 'عباسی',
        phone: '09120001122',
        email: 'amir@test.com',
        accessCode: 'PC-RESTOR',
        gender: 'male',
        age: 30,
        heightCm: 176,
        weightKg: 79,
        fitnessGoal: 'maintenance',
        injuryTags: const [],
        createdAt: now,
        updatedAt: now,
      ));

      final backupJson = db.exportFullDatabaseToJson();
      db.clearAllUserDataOnLogout();
      expect(db.getAllActiveAthletes().isEmpty, isTrue);

      final restoredCount = db.restoreFullDatabaseFromJson(backupJson);
      expect(restoredCount, equals(1));
      expect(db.getAthleteByAccessCode('PC-RESTOR')?.fullName, equals('امیر عباسی'));
    });
  });
}
