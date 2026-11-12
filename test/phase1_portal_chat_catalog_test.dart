import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/utils/number_parser.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/seed_catalog_data.dart';

void main() {
  group('1. Persian Number & Typography Sanitizer Tests', () {
    test('Converts Persian and Arabic digits to standard English digits', () {
      expect('۱۲۳۴۵۶۷۸۹۰'.toEnglishDigits(), equals('1234567890'));
      expect('١٢٣٤٥٦٧٨٩٠'.toEnglishDigits(), equals('1234567890'));
      expect(' ۷۵٫۵ '.toEnglishDigits(), equals('75.5'));
      expect('۸۲,۳'.toEnglishDigits(), equals('82.3'));
    });

    test('toCleanPersian fixes missing ZWNJ half-spaces accurately', () {
      expect('ماشینحساب'.toCleanPersian(), equals('ماشین‌حساب'));
      expect('عضلهسازی'.toCleanPersian(), equals('عضله‌سازی'));
      expect('چربیسوزی'.toCleanPersian(), equals('چربی‌سوزی'));
      expect('قالبهای آماده'.toCleanPersian(), equals('قالب‌های آماده'));
      expect('برنامهها'.toCleanPersian(), equals('برنامه‌ها'));
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
  });

  group('3. Athlete High-Entropy Access Code & Irreversible Password Hash Tests', () {
    test('Generates valid PC-XXXXXX alphanumeric access codes', () {
      final code = AthleteEntity.generateAccessCode();
      expect(code.startsWith('PC-'), isTrue);
      expect(code.length, equals(9));
    });

    test('OWASP M10: hashPassword never leaks Base64 plaintext and verifies accurately', () {
      const secretPass = 'MySuperSecretPass2026!';
      final base64Plain = base64Url.encode(utf8.encode(secretPass));
      final hashed = AthleteEntity.hashPassword(secretPass);

      expect(hashed.startsWith('MG-'), isTrue);
      // اطمینان از اینکه رشته Base64 پسورد به هیچ وجه داخل هش وجود ندارد
      expect(hashed.contains(base64Plain), isFalse);
      expect(AthleteEntity.verifyPasswordHash(secretPass, hashed), isTrue);
      expect(AthleteEntity.verifyPasswordHash('WrongPass', hashed), isFalse);
    });
  });

  group('4. Offline Database: Chat, Workout Logs, Auto-Draft & Safe Logout Protection', () {
    late LocalAppDatabase db;

    setUp(() {
      db = LocalAppDatabase.initInMemoryForTesting();
    });

    test('Safe Logout preserves unsynced offline records when preserveUnsyncedOfflineData is true', () {
      final syncedAth = AthleteEntity(
        id: 'ath_synced_1',
        firstName: 'سینک',
        lastName: 'شده',
        phone: '09121111111',
        gender: 'male',
        age: 25,
        heightCm: 175,
        weightKg: 75,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 'synced',
      );
      final unsyncedAth = AthleteEntity(
        id: 'ath_unsynced_2',
        firstName: 'آفلاین',
        lastName: 'سینک‌نشده',
        phone: '09122222222',
        gender: 'male',
        age: 25,
        heightCm: 175,
        weightKg: 75,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 'pending_insert',
      );

      db.upsertAthlete(syncedAth);
      db.upsertAthlete(unsyncedAth);
      expect(db.hasUnsyncedChanges(), isTrue);

      // خروج در حالت آفلاین (حفظ رکورد سینک‌نشده)
      db.clearAllUserDataOnLogout(preserveUnsyncedOfflineData: true);
      expect(db.getAthleteById('ath_synced_1'), isNull);
      expect(db.getAthleteById('ath_unsynced_2'), isNotNull);

      // پاکسازی کامل پس از سینک
      db.clearAllUserDataOnLogout(preserveUnsyncedOfflineData: false);
      expect(db.getAllActiveAthletes(), isEmpty);
    });
  });
}
