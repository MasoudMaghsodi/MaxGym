import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/features/athletes/domain/scientific_bio_calculator.dart';
import 'package:pro_coach_app/features/pdf_export/pdf_export_engine.dart';

void main() {
  group('1. Scientific Bio-Calculator Unit Tests', () {
    test('Calculates BMI & WHtR accurately for muscular athlete', () {
      final result = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 28,
        heightCm: 180,
        weightKg: 85,
        fitnessGoal: 'lean_bulk',
        waistCm: 81, // نسبت دور کمر به قد: 81 / 180 = 0.45 (ایده‌آل)
      );

      // BMI = 85 / (1.8 * 1.8) = 26.23 -> 26.2
      expect(result.bmi, closeTo(26.2, 0.1));
      expect(result.whtr, closeTo(0.45, 0.01));
      expect(result.whtrStatusEn, equals('Healthy & Athletic'));
      expect(result.formulaUsed, equals('Mifflin-St Jeor'));
    });

    test('Switches automatically to Katch-McArdle when Body Fat % is provided', () {
      final resultWithoutBF = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 30,
        heightCm: 175,
        weightKg: 80,
        fitnessGoal: 'weight_loss',
      );

      final resultWithBF = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 30,
        heightCm: 175,
        weightKg: 80,
        fitnessGoal: 'weight_loss',
        bodyFatPercent: 12.0, // درصد چربی مشخص -> فعال‌سازی Katch-McArdle
      );

      expect(resultWithoutBF.formulaUsed, equals('Mifflin-St Jeor'));
      expect(resultWithBF.formulaUsed, equals('Katch-McArdle (LBM)'));
      // LBM = 80 * (1 - 0.12) = 70.4 kg -> BMR = 370 + (21.6 * 70.4) = 1890.64 -> 1891
      expect(resultWithBF.bmrKcal, closeTo(1891, 2));
      // در هدف کاهش وزن، پروتئین باید 2.2 گرم به ازای هر کیلوگرم باشد (80 * 2.2 = 176g)
      expect(resultWithBF.proteinGrams, equals(176));
      expect(resultWithBF.fiberGrams, greaterThanOrEqualTo(20));
      expect(resultWithBF.waterLiters, closeTo(3.1, 0.1));
    });

    test('1RM Epley Calculator computes accurate max strength', () {
      // 100kg for 10 reps -> 100 * (1 + 10/30) = 133.3 kg
      final oneRm = ScientificBioCalculator.calculateOneRepMax(100, 10);
      expect(oneRm, closeTo(133.3, 0.1));

      expect(ScientificBioCalculator.calculateOneRepMax(120, 1), equals(120.0));
      expect(ScientificBioCalculator.calculateOneRepMax(0, 10), equals(0.0));
    });
  });

  group('2. PDF Dynamic File Naming Tests (Solar Hijri / Shamsi)', () {
    test('Formats filename strictly as [Athlete_Full_Name]_[Shamsi_Date].pdf', () {
      final sampleAthlete = AthleteEntity(
        id: 'uuid-1',
        firstName: 'Ali',
        lastName: 'Rezaei',
        phone: '09120000000',
        gender: 'male',
        age: 26,
        heightCm: 180,
        weightKg: 80,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: DateTime(2026, 11, 9),
        updatedAt: DateTime(2026, 11, 9),
      );

      // 2026-11-09 معادل 1405-08-18 شمسی است
      final fileName = PdfExportEngine.buildDynamicFileName(
        sampleAthlete,
        DateTime(2026, 11, 9),
      );

      expect(fileName, equals('Ali_Rezaei_1405-08-18.pdf'));
    });
  });
}
