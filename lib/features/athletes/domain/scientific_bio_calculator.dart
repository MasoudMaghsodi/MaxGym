class BioAnalysisResult {
  final double bmi;
  final String bmiCategoryFa;
  final String bmiCategoryEn;

  final double? whtr; // نسبت دور کمر به قد (دقیقترین شاخص برای بدنسازان)
  final String whtrStatusFa;
  final String whtrStatusEn;

  final int bmrKcal; // نرخ متابولیسم پایه
  final int tdeeKcal; // کالری تثبیت
  final int targetCalories; // کالری بر اساس هدف ورزشکار
  final String formulaUsed; // Mifflin-St Jeor یا Katch-McArdle

  // ماکروها و میکروهای روزانه (بر اساس هدف)
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int fiberGrams;
  final double waterLiters;

  const BioAnalysisResult({
    required this.bmi,
    required this.bmiCategoryFa,
    required this.bmiCategoryEn,
    this.whtr,
    required this.whtrStatusFa,
    required this.whtrStatusEn,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.targetCalories,
    required this.formulaUsed,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.waterLiters,
  });
}

class ScientificBioCalculator {
  /// تحلیل کامل بیومتریک و محاسبه علمی درشتمغذیها (Macros) و ریزمغذیها
  static BioAnalysisResult analyze({
    required String gender, // 'male' | 'female'
    required int age,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal, // 'weight_loss', 'lean_bulk', 'muscle_gain', 'maintenance'
    double? bodyFatPercent,
    double? waistCm,
    double activityMultiplier = 1.55, // پیشفرض: ورزشکار با ۳ تا ۵ جلسه تمرین در هفته
  }) {
    final heightM = (heightCm > 0 ? heightCm : 170) / 100.0;
    final safeWeight = weightKg > 0 ? weightKg : 70.0;

    // ۱. محاسبه BMI
    final bmi = safeWeight / (heightM * heightM);
    String bmiFa;
    String bmiEn;
    if (bmi < 18.5) {
      bmiFa = 'کمبود وزن';
      bmiEn = 'Underweight';
    } else if (bmi < 25.0) {
      bmiFa = 'وزن نرمال';
      bmiEn = 'Normal Weight';
    } else if (bmi < 30.0) {
      bmiFa = 'اضافه وزن / توده عضلانی بالا';
      bmiEn = 'Overweight / Muscular';
    } else {
      bmiFa = 'چاقی (نیاز به بررسی درصد چربی)';
      bmiEn = 'Obese Class';
    }

    // ۲. محاسبه WHtR (نسبت دور کمر به قد - ضد خطای BMI در بدنسازان عضلانی)
    double? whtr;
    String whtrFa = 'ثبت نشده (دور کمر را وارد کنید)';
    String whtrEn = 'N/A (Enter Waist size)';
    if (waistCm != null && waistCm > 0 && heightCm > 0) {
      whtr = waistCm / heightCm;
      if (whtr < 0.43) {
        whtrFa = 'تفکیک بسیار بالا (Lean)';
        whtrEn = 'Extremely Lean';
      } else if (whtr < 0.50) {
        whtrFa = 'ایدهآل و سلامت کامل قلبی';
        whtrEn = 'Healthy & Athletic';
      } else if (whtr < 0.58) {
        whtrFa = 'چربی شکمی متوسط';
        whtrEn = 'Elevated Central Fat';
      } else {
        whtrFa = 'چربی احشایی بالا (اولویت چربیسوزی)';
        whtrEn = 'High Visceral Fat Risk';
      }
    }

    // ۳. محاسبه BMR (سوئیچ هوشمند بین Katch-McArdle و Mifflin-St Jeor)
    double bmr;
    String formula;
    if (bodyFatPercent != null && bodyFatPercent > 3 && bodyFatPercent < 60) {
      final leanBodyMass = safeWeight * (1.0 - (bodyFatPercent / 100.0));
      bmr = 370 + (21.6 * leanBodyMass);
      formula = 'Katch-McArdle (LBM)';
    } else {
      final isMale = gender.toLowerCase() == 'male';
      bmr = (10 * safeWeight) +
          (6.25 * heightCm) -
          (5 * age) +
          (isMale ? 5 : -161);
      formula = 'Mifflin-St Jeor';
    }

    final tdee = (bmr * activityMultiplier).round();

    // ۴. تنظیم کالری و ضرایب ماکرو بر اساس هدف ورزشکار
    int targetKcal = tdee;
    double proteinPerKg = 2.0;
    double fatCalorieRatio = 0.25;

    switch (fitnessGoal) {
      case 'weight_loss': // چربیسوزی و کات
        targetKcal = (tdee * 0.80).round(); // ۲۰٪ کسری کالری علمی
        proteinPerKg = 2.2; // پروتئین بالاتر برای حفظ عضله در دوران کات
        fatCalorieRatio = 0.25;
        break;
      case 'lean_bulk': // عضلهسازی خشک
        targetKcal = (tdee * 1.10).round(); // ۱۰٪ مازاد کالری کنترلشده
        proteinPerKg = 2.0;
        fatCalorieRatio = 0.25;
        break;
      case 'muscle_gain': // افزایش حجم و وزن
        targetKcal = (tdee * 1.20).round(); // ۲۰٪ مازاد کالری
        proteinPerKg = 1.9;
        fatCalorieRatio = 0.28;
        break;
      case 'maintenance': // تثبیت وزن و آمادگی جسمانی
      default:
        targetKcal = tdee;
        proteinPerKg = 1.8;
        fatCalorieRatio = 0.28;
        break;
    }

    // ۵. محاسبه گرم دقیق پروتئین، چربی، کربوهیدرات، فیبر و آب
    final proteinGrams = (safeWeight * proteinPerKg).round();
    final proteinCalories = proteinGrams * 4;

    final fatCalories = (targetKcal * fatCalorieRatio).round();
    final fatGrams = (fatCalories / 9).round();

    final remainingCalories =
        (targetKcal - proteinCalories - fatCalories).clamp(200, 10000);
    final carbsGrams = (remainingCalories / 4).round();

    // استاندارد علمی فیبر: ۱۴ گرم به ازای هر ۱۰۰۰ کیلوکالری
    final fiberGrams = ((targetKcal / 1000.0) * 14).round().clamp(20, 50);

    // استاندارد علمی آب مصرفی: وزن × 0.033 + 0.5 لیتر بابت تعریق تمرین
    final waterLiters =
        double.parse(((safeWeight * 0.033) + 0.5).toStringAsFixed(1));

    return BioAnalysisResult(
      bmi: double.parse(bmi.toStringAsFixed(1)),
      bmiCategoryFa: bmiFa,
      bmiCategoryEn: bmiEn,
      whtr: whtr != null ? double.parse(whtr.toStringAsFixed(2)) : null,
      whtrStatusFa: whtrFa,
      whtrStatusEn: whtrEn,
      bmrKcal: bmr.round(),
      tdeeKcal: tdee,
      targetCalories: targetKcal,
      formulaUsed: formula,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      fiberGrams: fiberGrams,
      waterLiters: waterLiters,
    );
  }

  /// محاسبه یک تکرار بیشینه (1RM - One Rep Max) با فرمول ترکیبی Epley / Brzycki
  static double calculateOneRepMax(double weightMoved, int repsPerformed) {
    if (repsPerformed <= 0 || weightMoved <= 0) return 0;
    if (repsPerformed == 1) return weightMoved;
    // فرمول Epley
    final epley = weightMoved * (1 + (repsPerformed / 30.0));
    return double.parse(epley.toStringAsFixed(1));
  }
}
