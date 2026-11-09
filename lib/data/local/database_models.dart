import 'dart:convert';

/// انواع ستهای پیشرفته بدنسازی
enum SetType {
  normal,     // ست معمولی
  superset,   // سوپرست (۲ حرکت پشت سر هم)
  triset,     // تریست (۳ حرکت پشت سر هم)
  giantSet,   // جاینتست (۴ حرکت یا بیشتر)
  dropSet,    // دراپست (کاهش وزنه بدون استراحت)
  restPause,  // رست-پاز (استراحت کوتاه ۱۰-۱۵ ثانیهای و ادامه)
}

/// سیستمهای اجرایی و کنترل سرعت (Execution Modifiers)
enum ExecutionModifier {
  normal,       // اجرای نرمال و کنترلشده
  tempo,        // تمپو دقیق (مثلاً 3-1-1-0)
  explosive,    // انفجاری / سرعتی (Power)
  partialLow,   // دامنه حرکتی نیمه پایین
  partialHigh,  // دامنه حرکتی نیمه بالا
  isometric,    // مکث ایزومتریک در اوج انقباض
}

/// پیکربندی دقیق هر ست در یک حرکت ورزشی
class SingleSetConfig {
  final int setNumber;
  final String reps; // مثلاً "8-10" یا "12" یا "Failure" یا "45s"
  final String tempo; // مثلاً "3-1-1-0"
  final int restSeconds; // مثلاً 60 یا 90 ثانیه
  final int? rir; // Reps in Reserve (تکرار باقیمانده تا ناتوانی: 0 تا 4)
  final bool isDropSet;
  final ExecutionModifier modifier;

  const SingleSetConfig({
    required this.setNumber,
    this.reps = '10-12',
    this.tempo = '2-0-1-0',
    this.restSeconds = 60,
    this.rir = 1,
    this.isDropSet = false,
    this.modifier = ExecutionModifier.normal,
  });

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'reps': reps,
        'tempo': tempo,
        'restSeconds': restSeconds,
        'rir': rir,
        'isDropSet': isDropSet,
        'modifier': modifier.name,
      };

  factory SingleSetConfig.fromJson(Map<String, dynamic> json) {
    return SingleSetConfig(
      setNumber: json['setNumber'] as int? ?? 1,
      reps: json['reps'] as String? ?? '10-12',
      tempo: json['tempo'] as String? ?? '2-0-1-0',
      restSeconds: json['restSeconds'] as int? ?? 60,
      rir: json['rir'] as int?,
      isDropSet: json['isDropSet'] as bool? ?? false,
      modifier: ExecutionModifier.values.firstWhere(
        (e) => e.name == (json['modifier'] ?? 'normal'),
        orElse: () => ExecutionModifier.normal,
      ),
    );
  }

  static String encodeList(List<SingleSetConfig> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SingleSetConfig> decodeList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((e) => SingleSetConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// آیتم غذایی به همراه گزینههای جایگزین (منطق "یا" / OR Logic)
class MealFoodRow {
  final String foodNameFa;
  final String foodNameEn;
  final String amountFa; // مثلاً "۱۵۰ گرم" یا "۲ کف دست"
  final String amountEn; // e.g., "150g" or "2 Palms"
  final List<String> alternativesFa; // مثلاً ["۱۵۰ گرم فیله ماهی", "۵ عدد سفیده تخممرغ"]
  final List<String> alternativesEn;

  const MealFoodRow({
    required this.foodNameFa,
    required this.foodNameEn,
    required this.amountFa,
    required this.amountEn,
    this.alternativesFa = const [],
    this.alternativesEn = const [],
  });

  Map<String, dynamic> toJson() => {
        'foodNameFa': foodNameFa,
        'foodNameEn': foodNameEn,
        'amountFa': amountFa,
        'amountEn': amountEn,
        'alternativesFa': alternativesFa,
        'alternativesEn': alternativesEn,
      };

  factory MealFoodRow.fromJson(Map<String, dynamic> json) {
    return MealFoodRow(
      foodNameFa: json['foodNameFa'] ?? '',
      foodNameEn: json['foodNameEn'] ?? '',
      amountFa: json['amountFa'] ?? '',
      amountEn: json['amountEn'] ?? '',
      alternativesFa: List<String>.from(json['alternativesFa'] ?? []),
      alternativesEn: List<String>.from(json['alternativesEn'] ?? []),
    );
  }
}

/// ساختار یک وعده کامل غذایی (مثلاً صبحانه یا بعد از تمرین)
class DietMealSlot {
  final String slotId; // breakfast, snack1, lunch, pre_workout, post_workout, dinner
  final String titleFa;
  final String titleEn;
  final String timeRange; // مثلاً "08:00 - 09:00"
  final List<MealFoodRow> items;

  const DietMealSlot({
    required this.slotId,
    required this.titleFa,
    required this.titleEn,
    this.timeRange = '',
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'titleFa': titleFa,
        'titleEn': titleEn,
        'timeRange': timeRange,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory DietMealSlot.fromJson(Map<String, dynamic> json) {
    return DietMealSlot(
      slotId: json['slotId'] ?? '',
      titleFa: json['titleFa'] ?? '',
      titleEn: json['titleEn'] ?? '',
      timeRange: json['timeRange'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => MealFoodRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static String encodeList(List<DietMealSlot> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<DietMealSlot> decodeList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((e) => DietMealSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// ردیف تجویز مکمل در پروتکل مکملها
class SupplementPrescriptionItem {
  final String supplementId;
  final String nameFa;
  final String nameEn;
  final String dosageFa; // مثلاً "۱ اسکوپ (۳۰ گرم)"
  final String dosageEn; // "1 Scoop (30g)"
  final String timingFa; // "بلافاصله بعد از تمرین"
  final String timingEn; // "Immediately Post-Workout"
  final bool onlyTrainingDays; // فقط روزهای تمرین یا همه روزها؟
  final String notesFa;
  final String notesEn;

  const SupplementPrescriptionItem({
    required this.supplementId,
    required this.nameFa,
    required this.nameEn,
    required this.dosageFa,
    required this.dosageEn,
    required this.timingFa,
    required this.timingEn,
    this.onlyTrainingDays = false,
    this.notesFa = '',
    this.notesEn = '',
  });

  Map<String, dynamic> toJson() => {
        'supplementId': supplementId,
        'nameFa': nameFa,
        'nameEn': nameEn,
        'dosageFa': dosageFa,
        'dosageEn': dosageEn,
        'timingFa': timingFa,
        'timingEn': timingEn,
        'onlyTrainingDays': onlyTrainingDays,
        'notesFa': notesFa,
        'notesEn': notesEn,
      };

  factory SupplementPrescriptionItem.fromJson(Map<String, dynamic> json) {
    return SupplementPrescriptionItem(
      supplementId: json['supplementId'] ?? '',
      nameFa: json['nameFa'] ?? '',
      nameEn: json['nameEn'] ?? '',
      dosageFa: json['dosageFa'] ?? '',
      dosageEn: json['dosageEn'] ?? '',
      timingFa: json['timingFa'] ?? '',
      timingEn: json['timingEn'] ?? '',
      onlyTrainingDays: json['onlyTrainingDays'] ?? false,
      notesFa: json['notesFa'] ?? '',
      notesEn: json['notesEn'] ?? '',
    );
  }

  static String encodeList(List<SupplementPrescriptionItem> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SupplementPrescriptionItem> decodeList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((e) =>
            SupplementPrescriptionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
