import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/features/athletes/domain/scientific_bio_calculator.dart';

void main() {
  group('ScientificBioCalculator Tests', () {
    test('Calculates BMI and categories correctly', () {
      final analysis = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 25,
        heightCm: 180,
        weightKg: 75,
        fitnessGoal: 'muscle_gain',
      );

      // BMI = 75 / (1.8^2) = 23.15
      expect(analysis.bmi, closeTo(23.15, 0.1));
      expect(analysis.bmiCategoryFa, contains('نرمال'));
    });

    test('Calculates BMR and TDEE correctly', () {
      final analysisMifflin = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 30,
        heightCm: 175,
        weightKg: 80,
        fitnessGoal: 'weight_loss',
      );
      expect(analysisMifflin.bmrKcal, greaterThan(1500));
      expect(analysisMifflin.tdeeKcal, greaterThan(analysisMifflin.bmrKcal));
      expect(analysisMifflin.formulaUsed, 'Mifflin-St Jeor');

      final analysisKatch = ScientificBioCalculator.analyze(
        gender: 'male',
        age: 30,
        heightCm: 175,
        weightKg: 80,
        bodyFatPercent: 15,
        fitnessGoal: 'weight_loss',
      );
      expect(analysisKatch.bmrKcal, greaterThan(1500));
      expect(analysisKatch.formulaUsed, contains('Katch-McArdle'));
    });

    test('Estimates 1RM accurately', () {
      final oneRm = ScientificBioCalculator.calculateOneRepMax(100, 5);
      // Epley: 100 * (1 + 5/30) = 116.7
      expect(oneRm, closeTo(116.7, 0.2));
    });
  });
}
