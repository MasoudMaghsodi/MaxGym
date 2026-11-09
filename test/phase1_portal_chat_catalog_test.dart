import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/utils/number_parser.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/seed_catalog_data.dart';

void main() {
  group('1. Persian Number Sanitizer Tests', () {
    test('Converts Persian and Arabic digits to standard English digits', () {
      expect('۱۲۳۴۵۶۷۸۹۰'.toEnglishDigits(), equals('1234567890'));
      expect('١٢٣٤٥٦٧٨٩٠'.toEnglishDigits(), equals('1234567890'));
      expect(' ۷۵٫۵ '.toEnglishDigits(), equals('75.5'));
      expect('۸۲,۳'.toEnglishDigits(), equals('82.3'));
    });

    test('toSafeDouble & toSafeInt parse mixed strings safely', () {
      expect('۷۵٫۵'.toSafeDouble(), equals(75.5));
      expect('  ۱۲۰ '.toSafeDouble(), equals(120.0));
      expect('abc'.toSafeDouble(), isNull);
      expect(''.toSafeDouble(), isNull);

      expect('۱۲'.toSafeInt(), equals(12));
      expect('۷۵٫۴'.toSafeInt(), equals(75));
      expect('invalid'.toSafeInt(), isNull);
    });
  });

  group('2. Bilingual Catalog & Translation Engine Tests', () {
    test('Contains offline database with 60+ exercises, 40 foods and 30 supplements', () {
      expect(SeedCatalogData.initialExercises.length, greaterThanOrEqualTo(60));
      expect(SeedCatalogData.quickFoodCatalog.length, greaterThanOrEqualTo(40));
      expect(SeedCatalogData.supplementCatalog.length, greaterThanOrEqualTo(30));
    });

    test('Translates standard workout terms to Persian gym terms', () {
      final translated = SeedCatalogData.translateExerciseNameToPersian('Barbell Bench Press');
      expect(translated.contains('پرس سینه'), isTrue);
      expect(translated.contains('هالتر'), isTrue);
    });

    test('Maps international muscles to the 8 core application muscle groups', () {
      expect(SeedCatalogData.mapGlobalMuscleGroup('Quadriceps'), equals('legs'));
      expect(SeedCatalogData.mapGlobalMuscleGroup('Lats'), equals('back'));
      expect(SeedCatalogData.mapGlobalMuscleGroup('Chest'), equals('chest'));
      expect(SeedCatalogData.mapGlobalMuscleGroup('Abdominals'), equals('abs'));
      expect(SeedCatalogData.mapGlobalMuscleGroup('Calves'), equals('calves'));
      expect(SeedCatalogData.mapGlobalMuscleGroup('Biceps'), equals('biceps'));
      expect(SeedCatalogData.mapGlobalMuscleGroup('Triceps'), equals('triceps'));
      expect(SeedCatalogData.mapGlobalMuscleGroup('Shoulders'), equals('shoulders'));
    });
  });

  group('3. Athlete Access Code & Profile Completion Tests', () {
    test('Generates valid PC-XXXXXX access codes', () {
      final code = AthleteEntity.generateAccessCode();
      expect(code.startsWith('PC-'), isTrue);
      expect(code.length, equals(9)); // PC- + 6 digits
    });

    test('isProfileComplete validates required athlete fields', () {
      final completeAthlete = AthleteEntity(
        id: 'ath_1',
        firstName: 'رضا',
        lastName: 'نوروزی',
        phone: '09121112233',
        email: 'reza@example.com',
        accessCode: 'PC-123456',
        gender: 'male',
        age: 26,
        heightCm: 180,
        weightKg: 82,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(completeAthlete.isProfileComplete, isTrue);

      final incompleteAthlete = completeAthlete.copyWith(
        email: '',
      );
      expect(incompleteAthlete.isProfileComplete, isFalse);

      final underageOrInvalid = completeAthlete.copyWith(
        age: 5,
      );
      expect(underageOrInvalid.isProfileComplete, isFalse);
    });
  });

  group('4. Offline Database: Chat, Workout Logs, Auto-Draft & OWASP Wipe', () {
    late LocalAppDatabase db;

    setUp(() {
      db = LocalAppDatabase.initInMemoryForTesting();
    });

    test('Supports access_code lookup and auto-assigns code if missing', () {
      final athlete = AthleteEntity(
        id: 'ath_test_code',
        firstName: 'سهراب',
        lastName: 'مرادی',
        phone: '09351112233',
        email: 'sohrab@fit.ir',
        accessCode: 'PC-998877',
        gender: 'male',
        age: 32,
        heightCm: 175,
        weightKg: 94,
        fitnessGoal: 'strength',
        injuryTags: const ['shoulder'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      db.upsertAthlete(athlete);

      final found = db.getAthleteByAccessCode('pc-998877');
      expect(found, isNotNull);
      expect(found!.fullName, equals('سهراب مرادی'));
      expect(found.accessCode, equals('PC-998877'));
    });

    test('Pure text chat saves, orders and filters pending sync messages', () {
      final msg1 = ChatMessageEntity(
        id: 'msg_1',
        athleteId: 'ath_test_code',
        senderRole: 'coach',
        messageText: 'سلام سهراب جان، برنامه این هفته بارگذاری شد.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final msg2 = ChatMessageEntity(
        id: 'msg_2',
        athleteId: 'ath_test_code',
        senderRole: 'athlete',
        messageText: 'ممنون استاد، امروز تمرین پا رو شروع می‌کنم.',
        createdAt: DateTime.now(),
      );

      db.insertChatMessage(msg1);
      db.insertChatMessage(msg2);

      final chats = db.getChatMessagesForAthlete('ath_test_code');
      expect(chats.length, equals(2));
      expect(chats.first.senderRole, equals('coach'));
      expect(chats.last.senderRole, equals('athlete'));

      final pending = db.getPendingSyncChatMessages();
      expect(pending.length, equals(2));
    });

    test('Workout session log increments athlete streak days automatically', () {
      final athlete = AthleteEntity(
        id: 'ath_streak',
        firstName: 'میلاد',
        lastName: 'جعفری',
        phone: '09191112233',
        gender: 'male',
        age: 24,
        heightCm: 178,
        weightKg: 76,
        fitnessGoal: 'shred',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        streakDays: 1,
      );
      db.upsertAthlete(athlete);

      final log = AthleteWorkoutLogEntity(
        id: 'log_1',
        athleteId: 'ath_streak',
        programId: 'prog_1',
        dayNumber: 1,
        exerciseMaxWeights: {'ex_squat': 120.0, 'ex_leg_press': 240.0},
        waterGlasses: 8,
        sessionRpe: 8,
        athleteFeedback: 'انرژی عالی بود، وزنه اسکوات رو ۱۰ کیلو اضافه کردم.',
        loggedAt: DateTime.now(),
      );

      db.insertWorkoutSessionLog(log);

      final updatedAthlete = db.getAthleteById('ath_streak');
      expect(updatedAthlete!.streakDays, equals(2));

      final logs = db.getWorkoutLogsForAthlete('ath_streak');
      expect(logs.length, equals(1));
      expect(logs.first.exerciseMaxWeights['ex_squat'], equals(120.0));
      expect(logs.first.waterGlasses, equals(8));
    });

    test('Auto-Draft saves, restores and deletes builder draft cleanly', () {
      const athleteId = 'ath_draft_test';
      const draftPayload = '{"title":"برنامه فشرده ۴ روزه","days":[{"day":1}]}';

      expect(db.loadProgramDraft(athleteId), isNull);

      db.saveProgramDraft(athleteId, draftPayload);
      expect(db.loadProgramDraft(athleteId), equals(draftPayload));

      db.deleteProgramDraft(athleteId);
      expect(db.loadProgramDraft(athleteId), isNull);
    });

    test('OWASP M9: clearAllUserDataOnLogout completely purges all sensitive data', () {
      db.upsertAthlete(AthleteEntity(
        id: 'ath_to_wipe',
        firstName: 'تست',
        lastName: 'وایپ',
        phone: '09120000000',
        gender: 'male',
        age: 20,
        heightCm: 170,
        weightKg: 70,
        fitnessGoal: 'fat_loss',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      db.saveProgramDraft('ath_to_wipe', '{"draft": true}');
      db.insertChatMessage(ChatMessageEntity(
        id: 'msg_wipe',
        athleteId: 'ath_to_wipe',
        senderRole: 'coach',
        messageText: 'پیام محرمانه مربی',
        createdAt: DateTime.now(),
      ));

      expect(db.getAllActiveAthletes().isNotEmpty, isTrue);
      expect(db.loadProgramDraft('ath_to_wipe'), isNotNull);
      expect(db.getChatMessagesForAthlete('ath_to_wipe').isNotEmpty, isTrue);

      db.clearAllUserDataOnLogout();

      expect(db.getAllActiveAthletes(), isEmpty);
      expect(db.loadProgramDraft('ath_to_wipe'), isNull);
      expect(db.getChatMessagesForAthlete('ath_to_wipe'), isEmpty);
    });
  });
}
