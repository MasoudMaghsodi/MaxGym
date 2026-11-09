import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/utils/number_parser.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/local/seed_catalog_data.dart';
import 'package:pro_coach_app/features/athletes/domain/scientific_bio_calculator.dart';
import 'package:pro_coach_app/features/pdf_export/pdf_export_engine.dart';

void main() {
  group('1. Persian/Arabic Digit Sanitizer Tests (Audit Fix #2)', () {
    test('Converts Persian and Arabic numerals and decimal separators to English', () {
      expect('۷۵.۵'.toSafeDouble(), equals(75.5));
      expect('۸۲٫۵'.toSafeDouble(), equals(82.5));
      expect('١٢٠'.toSafeInt(), equals(120));
      expect('۰۹۱۲۱۱۱۲۲۳۳'.toEnglishDigits(), equals('09121112233'));
    });
  });

  group('2. Scientific Bio-Calculator & 800+ Exercise Translator Tests', () {
    test('Calculates BMI & WHtR accurately for muscular athlete', () {
      final result = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 28,
        heightCm: 180,
        weightKg: 85,
        fitnessGoal: 'lean_bulk',
        waistCm: 81,
      );

      expect(result.bmi, closeTo(26.2, 0.1));
      expect(result.whtr, closeTo(0.45, 0.01));
      expect(result.whtrStatusEn, equals('Healthy & Athletic'));
      expect(result.formulaUsed, equals('Mifflin-St Jeor'));
    });

    test('Switches automatically to Katch-McArdle when Body Fat % is provided', () {
      final resultWithBF = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 30,
        heightCm: 175,
        weightKg: 80,
        fitnessGoal: 'weight_loss',
        bodyFatPercent: 12.0,
      );

      expect(resultWithBF.formulaUsed, equals('Katch-McArdle (LBM)'));
      expect(resultWithBF.bmrKcal, closeTo(1891, 2));
      expect(resultWithBF.proteinGrams, equals(176));
    });

    test('Auto-translates global English exercise names to Persian gym terms', () {
      final fa = SeedCatalogData.translateEnglishExerciseToPersian(
          'Incline Dumbbell Bench Press');
      expect(fa, contains('بالاسینه'));
      expect(fa, contains('دمبل'));
    });
  });

  group('3. PDF Dynamic File Naming & Access Code Tests', () {
    test('Formats filename strictly as [Athlete_Full_Name]_[Shamsi_Date].pdf', () {
      final sampleAthlete = AthleteEntity(
        id: 'uuid-1',
        firstName: 'Ali',
        lastName: 'Rezaei',
        phone: '09120000000',
        email: 'ali@gym.com',
        accessCode: 'PC-998877',
        gender: 'male',
        age: 26,
        heightCm: 180,
        weightKg: 80,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: DateTime(2026, 11, 9),
        updatedAt: DateTime(2026, 11, 9),
      );

      final fileName = PdfExportEngine.buildDynamicFileName(
        sampleAthlete,
        DateTime(2026, 11, 9),
      );

      expect(fileName, equals('Ali_Rezaei_1405-08-18.pdf'));
      expect(sampleAthlete.isProfileComplete, isTrue);
    });
  });
}
