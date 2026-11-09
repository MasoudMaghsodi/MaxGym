import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';

void main() {
  late LocalAppDatabase db;

  setUp(() {
    db = LocalAppDatabase.initInMemoryForTesting();
  });

  group('Rich Catalogs, Auto-Draft, Pure Text Chat & Full Backup/Restore Tests', () {
    test('Seeds expanded exercises, Persian foods, and 35+ supplements/vitamins', () {
      expect(db.getExercisesCatalog().length, greaterThanOrEqualTo(45));
      expect(db.getFoodsCatalog().length, greaterThanOrEqualTo(30));
      expect(db.getSupplementsCatalog().length, greaterThanOrEqualTo(35));

      // تست ایمپورت دستهای بانک جهانی ۸۰۰ حرکت
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

    test('Generates 6-digit Athlete Access Code, saves Auto-Draft, and logs Pure Text Chat', () {
      final now = DateTime.now();
      final athlete = AthleteEntity(
        id: 'ath-500',
        firstName: 'کیوان',
        lastName: 'نوری',
        phone: '09121234567',
        email: '', // ایمیل خالی -> پروفایل ناقص است
        gender: 'male',
        age: 27,
        heightCm: 180,
        weightKg: 82,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: now,
        updatedAt: now,
      );

      db.upsertAthlete(athlete);
      final savedAth = db.getAthleteById('ath-500')!;
      expect(savedAth.accessCode, startsWith('PC-'));
      expect(savedAth.isProfileComplete, isFalse); // چون ایمیل هنوز وارد نشده

      // ورود ورزشکار با کد اختصاصی
      final foundByCode = db.getAthleteByAccessCode(savedAth.accessCode);
      expect(foundByCode?.id, equals('ath-500'));

      // تست ذخیره و بازیابی خودکار پیشنویس برنامه (Auto-Draft)
      final draft = FullProgramEntity(
        id: 'draft-1',
        athleteId: 'ath-500',
        title: 'پیشنویس نیمهکاره',
        startDate: now,
        days: const [],
        dietMeals: const [],
        supplements: const [],
        updatedAt: now,
      );
      db.saveProgramDraft('ath-500', draft);
      expect(db.getProgramDraft('ath-500')?.title, equals('پیشنویس نیمهکاره'));
      db.clearProgramDraft('ath-500');
      expect(db.getProgramDraft('ath-500'), isNull);

      // تست چت متنی خالص بین مربی و شاگرد
      db.insertChatMessage(ChatMessageEntity(
        id: 'msg-1',
        athleteId: 'ath-500',
        senderRole: 'athlete',
        messageText: 'سلام استاد، امروز وزنه پرس سینه رو ۵ کیلو اضافه کردم!',
        createdAt: now,
      ));
      expect(db.getChatMessagesForAthlete('ath-500').length, equals(1));
      expect(db.getPendingSyncChatMessages().length, equals(1));
    });

    test('Exports full database to JSON and restores it after wipe', () {
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
