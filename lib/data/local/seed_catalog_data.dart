class ExerciseSeedItem {
  final String id;
  final String nameFa;
  final String nameEn;
  final String targetMuscle; // chest, back, shoulders, biceps, triceps, legs, abs, calves
  final String equipment; // barbell, dumbbell, cable, machine, bodyweight
  final String imageStartUrl;
  final String imageEndUrl;
  final List<String> contraindicatedInjuries; // lower_back, knee, shoulder, neck, wrist

  const ExerciseSeedItem({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.targetMuscle,
    required this.equipment,
    required this.imageStartUrl,
    required this.imageEndUrl,
    this.contraindicatedInjuries = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameFa': nameFa,
        'nameEn': nameEn,
        'targetMuscle': targetMuscle,
        'equipment': equipment,
        'imageStartUrl': imageStartUrl,
        'imageEndUrl': imageEndUrl,
        'contraindicatedInjuries': contraindicatedInjuries,
      };
}

class SeedCatalogData {
  static const String _cdnBase =
      'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises';

  /// لیست حرکات پایه بدنسازی به دو زبان فارسی و انگلیسی + لینک تصاویر شروع و پایان + تگهای آسیبدیدگی
  static const List<ExerciseSeedItem> initialExercises = [
    // --- CHEST (سینه) ---
    ExerciseSeedItem(
      id: 'Barbell_Bench_Press_-_Medium_Grip',
      nameFa: 'پرس سینه هالتر',
      nameEn: 'Barbell Bench Press',
      targetMuscle: 'chest',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Bench_Press_-_Medium_Grip/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Bench_Press_-_Medium_Grip/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Incline_Dumbbell_Press',
      nameFa: 'پرس بالاسینه دمبل',
      nameEn: 'Incline Dumbbell Press',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Incline_Dumbbell_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Incline_Dumbbell_Press/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Dumbbell_Flyes',
      nameFa: 'قفسه سینه دمبل (فلای)',
      nameEn: 'Dumbbell Chest Flyes',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Dumbbell_Flyes/0.jpg',
      imageEndUrl: '$_cdnBase/Dumbbell_Flyes/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Cable_Crossover',
      nameFa: 'کراساور سیمکش',
      nameEn: 'Cable Crossover',
      targetMuscle: 'chest',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Cable_Crossover/0.jpg',
      imageEndUrl: '$_cdnBase/Cable_Crossover/1.jpg',
    ),

    // --- BACK (زیربغل و پشت) ---
    ExerciseSeedItem(
      id: 'Wide-Grip_Lat_Pulldown',
      nameFa: 'لت سیمکش دست باز از جلو',
      nameEn: 'Wide-Grip Lat Pulldown',
      targetMuscle: 'back',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Wide-Grip_Lat_Pulldown/0.jpg',
      imageEndUrl: '$_cdnBase/Wide-Grip_Lat_Pulldown/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Bent_Over_Barbell_Row',
      nameFa: 'زیربغل هالتر خم',
      nameEn: 'Bent-Over Barbell Row',
      targetMuscle: 'back',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Bent_Over_Barbell_Row/0.jpg',
      imageEndUrl: '$_cdnBase/Bent_Over_Barbell_Row/1.jpg',
      contraindicatedInjuries: ['lower_back'],
    ),
    ExerciseSeedItem(
      id: 'Seated_Cable_Rows',
      nameFa: 'زیربغل قایقی (پشت دست جمع)',
      nameEn: 'Seated Cable Row',
      targetMuscle: 'back',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Seated_Cable_Rows/0.jpg',
      imageEndUrl: '$_cdnBase/Seated_Cable_Rows/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'One-Arm_Dumbbell_Row',
      nameFa: 'زیربغل تک دمبل خم (ارهای)',
      nameEn: 'One-Arm Dumbbell Row',
      targetMuscle: 'back',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/One-Arm_Dumbbell_Row/0.jpg',
      imageEndUrl: '$_cdnBase/One-Arm_Dumbbell_Row/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Barbell_Deadlift',
      nameFa: 'ددلیفت هالتر کلاسیک',
      nameEn: 'Barbell Deadlift',
      targetMuscle: 'back',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Deadlift/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Deadlift/1.jpg',
      contraindicatedInjuries: ['lower_back', 'knee'],
    ),

    // --- SHOULDERS (سرشانه) ---
    ExerciseSeedItem(
      id: 'Seated_Dumbbell_Press',
      nameFa: 'پرس سرشانه دمبل نشسته',
      nameEn: 'Seated Dumbbell Shoulder Press',
      targetMuscle: 'shoulders',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Seated_Dumbbell_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Seated_Dumbbell_Press/1.jpg',
      contraindicatedInjuries: ['shoulder', 'neck'],
    ),
    ExerciseSeedItem(
      id: 'Side_Lateral_Raise',
      nameFa: 'نشرجانب دمبل ایستاده',
      nameEn: 'Dumbbell Lateral Raise',
      targetMuscle: 'shoulders',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Side_Lateral_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Side_Lateral_Raise/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Face_Pull',
      nameFa: 'فیسپول سیمکش (سرشانه خلفی)',
      nameEn: 'Cable Face Pull',
      targetMuscle: 'shoulders',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Face_Pull/0.jpg',
      imageEndUrl: '$_cdnBase/Face_Pull/1.jpg',
    ),

    // --- LEGS (پا و سرینی) ---
    ExerciseSeedItem(
      id: 'Barbell_Full_Squat',
      nameFa: 'اسکات کامل با هالتر',
      nameEn: 'Barbell Back Squat',
      targetMuscle: 'legs',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Full_Squat/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Full_Squat/1.jpg',
      contraindicatedInjuries: ['knee', 'lower_back'],
    ),
    ExerciseSeedItem(
      id: 'Leg_Press',
      nameFa: 'پرس پا دستگاه',
      nameEn: 'Machine Leg Press',
      targetMuscle: 'legs',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Leg_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Leg_Press/1.jpg',
      contraindicatedInjuries: ['knee'],
    ),
    ExerciseSeedItem(
      id: 'Leg_Extensions',
      nameFa: 'جلوپا دستگاه',
      nameEn: 'Leg Extensions',
      targetMuscle: 'legs',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Leg_Extensions/0.jpg',
      imageEndUrl: '$_cdnBase/Leg_Extensions/1.jpg',
      contraindicatedInjuries: ['knee'],
    ),
    ExerciseSeedItem(
      id: 'Lying_Leg_Curls',
      nameFa: 'پشت پا خوابیده دستگاه',
      nameEn: 'Lying Leg Curls',
      targetMuscle: 'legs',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Lying_Leg_Curls/0.jpg',
      imageEndUrl: '$_cdnBase/Lying_Leg_Curls/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Romanian_Deadlift',
      nameFa: 'ددلیفت رومانیایی (پشت پا هالتر)',
      nameEn: 'Romanian Deadlift (RDL)',
      targetMuscle: 'legs',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Romanian_Deadlift/0.jpg',
      imageEndUrl: '$_cdnBase/Romanian_Deadlift/1.jpg',
      contraindicatedInjuries: ['lower_back'],
    ),
    ExerciseSeedItem(
      id: 'Standing_Calf_Raises',
      nameFa: 'ساق پا ایستاده دستگاه',
      nameEn: 'Standing Calf Raises',
      targetMuscle: 'calves',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Standing_Calf_Raises/0.jpg',
      imageEndUrl: '$_cdnBase/Standing_Calf_Raises/1.jpg',
    ),

    // --- BICEPS & TRICEPS (جلوبازو و پشتبازو) ---
    ExerciseSeedItem(
      id: 'Barbell_Curl',
      nameFa: 'جلوبازو هالتر ایستاده',
      nameEn: 'Standing Barbell Curl',
      targetMuscle: 'biceps',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Curl/1.jpg',
      contraindicatedInjuries: ['wrist'],
    ),
    ExerciseSeedItem(
      id: 'Alternate_Hammer_Curl',
      nameFa: 'جلوبازو دمبل چکشی متناوب',
      nameEn: 'Alternating Hammer Curl',
      targetMuscle: 'biceps',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Alternate_Hammer_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Alternate_Hammer_Curl/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Triceps_Pushdown',
      nameFa: 'پشتبازو سیمکش ایستاده',
      nameEn: 'Cable Triceps Pushdown',
      targetMuscle: 'triceps',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Triceps_Pushdown/0.jpg',
      imageEndUrl: '$_cdnBase/Triceps_Pushdown/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'EZ-Bar_Skullcrusher',
      nameFa: 'پشتبازو هالتر خوابیده (اسکالکراشر)',
      nameEn: 'EZ-Bar Skullcrusher',
      targetMuscle: 'triceps',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/EZ-Bar_Skullcrusher/0.jpg',
      imageEndUrl: '$_cdnBase/EZ-Bar_Skullcrusher/1.jpg',
      contraindicatedInjuries: ['wrist', 'shoulder'],
    ),

    // --- ABS & CORE (شکم و میانتنه) ---
    ExerciseSeedItem(
      id: 'Cable_Crunch',
      nameFa: 'کرانچ شکم با سیمکش',
      nameEn: 'Kneeling Cable Crunch',
      targetMuscle: 'abs',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Cable_Crunch/0.jpg',
      imageEndUrl: '$_cdnBase/Cable_Crunch/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Hanging_Leg_Raise',
      nameFa: 'زیرشکم بارفیکس (بالا آوردن پا)',
      nameEn: 'Hanging Leg Raise',
      targetMuscle: 'abs',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Hanging_Leg_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Hanging_Leg_Raise/1.jpg',
      contraindicatedInjuries: ['lower_back', 'shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Plank',
      nameFa: 'پلانک ایزومتریک شکم',
      nameEn: 'Core Plank Hold',
      targetMuscle: 'abs',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Plank/0.jpg',
      imageEndUrl: '$_cdnBase/Plank/1.jpg',
    ),
  ];

  /// کاتالوگ دوزبانه مکملهای ورزشی برای انتخاب سریع مربی
  static const List<Map<String, String>> supplementCatalog = [
    {
      'id': 'whey_protein',
      'nameFa': 'پروتئین وی (Whey Protein)',
      'nameEn': 'Whey Protein Isolate/Concentrate',
      'defaultDosageFa': '۱ اسکوپ (۳۰ گرم)',
      'defaultDosageEn': '1 Scoop (30g)',
      'defaultTimingFa': 'بلافاصله بعد از تمرین',
      'defaultTimingEn': 'Immediately Post-Workout',
    },
    {
      'id': 'creatine',
      'nameFa': 'کراتین مونوهیدرات (Creatine)',
      'nameEn': 'Creatine Monohydrate',
      'defaultDosageFa': '۵ گرم (۱ قاشق چایخوری)',
      'defaultDosageEn': '5 Grams (1 Scoop)',
      'defaultTimingFa': 'بعد از تمرین همراه آب فراوان',
      'defaultTimingEn': 'Post-Workout with water',
    },
    {
      'id': 'bcaa_eaa',
      'nameFa': 'آمینو اسید شاخهدار (BCAA / EAA)',
      'nameEn': 'BCAA / EAA Intra-Amino',
      'defaultDosageFa': '۱ اسکوپ (۱۰ گرم)',
      'defaultDosageEn': '1 Scoop (10g)',
      'defaultTimingFa': 'حین تمرین (محلول در بطری آب)',
      'defaultTimingEn': 'Intra-Workout',
    },
    {
      'id': 'glutamine',
      'nameFa': 'ال-گلوتامین (L-Glutamine)',
      'nameEn': 'L-Glutamine',
      'defaultDosageFa': '۵ گرم',
      'defaultDosageEn': '5 Grams',
      'defaultTimingFa': 'قبل از خواب شبانه',
      'defaultTimingEn': 'Before Bedtime',
    },
    {
      'id': 'caffeine_pre',
      'nameFa': 'کافئین / پمپ (Pre-Workout)',
      'nameEn': 'Pre-Workout / Caffeine 200mg',
      'defaultDosageFa': '۱ اسکوپ یا ۱ عدد قرص ۲۰۰ میلیگرم',
      'defaultDosageEn': '1 Serving / 200mg Tab',
      'defaultTimingFa': '۳۰ دقیقه قبل از شروع تمرین',
      'defaultTimingEn': '30 Mins Pre-Workout',
    },
    {
      'id': 'omega3',
      'nameFa': 'امگا ۳ (روغن ماهی - Omega 3)',
      'nameEn': 'Omega-3 Fish Oil (1000mg)',
      'defaultDosageFa': '۱ تا ۲ عدد سافتژل',
      'defaultDosageEn': '1-2 Softgels',
      'defaultTimingFa': 'همراه وعده ناهار یا شام',
      'defaultTimingEn': 'With Lunch or Dinner',
    },
    {
      'id': 'multivitamin',
      'nameFa': 'مولتیویتامین مینرال ورزشی',
      'nameEn': 'Daily Sports Multivitamin',
      'defaultDosageFa': '۱ عدد قرص',
      'defaultDosageEn': '1 Tablet',
      'defaultTimingFa': 'همراه وعده صبحانه',
      'defaultTimingEn': 'With Breakfast',
    },
    {
      'id': 'zma',
      'nameFa': 'زد ام ای / منیزیم و زینک (ZMA)',
      'nameEn': 'ZMA (Zinc, Magnesium, B6)',
      'defaultDosageFa': '۲ عدد کپسول',
      'defaultDosageEn': '2 Capsules',
      'defaultTimingFa': '۳۰ دقیقه قبل از خواب با معده نیمهخالی',
      'defaultTimingEn': '30 Mins Before Bed',
    },
  ];

  /// بانک دوزبانه مواد غذایی پرکاربرد برای ساخت سریع رژیم بدون تایپ
  static const List<Map<String, String>> quickFoodCatalog = [
    {
      'nameFa': 'سینه مرغ گریل یا آبپز',
      'nameEn': 'Grilled Chicken Breast',
      'unitFa': '۱۵۰ گرم (۱.۵ کف دست)',
      'unitEn': '150g (1.5 Palms)',
    },
    {
      'nameFa': 'سفیده تخممرغ آبپز',
      'nameEn': 'Boiled Egg Whites',
      'unitFa': '۴ عدد سفیده + ۱ زرده',
      'unitEn': '4 Whites + 1 Whole Egg',
    },
    {
      'nameFa': 'فیله ماهی سفید یا سالمون',
      'nameEn': 'Grilled White Fish / Salmon',
      'unitFa': '۱۸۰ گرم',
      'unitEn': '180g Fillet',
    },
    {
      'nameFa': 'گوشت قرمز لخم (فیله گوساله)',
      'nameEn': 'Lean Beef Steak / Mince',
      'unitFa': '۱۲۰ گرم',
      'unitEn': '120g Cooked',
    },
    {
      'nameFa': 'برنج سفید یا قهوهای (پخته بدون روغن)',
      'nameEn': 'Steamed White / Brown Rice',
      'unitFa': '۸ تا ۱۰ قاشق غذاخوری (۱۵۰ گرم)',
      'unitEn': '150g Cooked (1 Cup)',
    },
    {
      'nameFa': 'جو دوسر پرک (اوتمیل)',
      'nameEn': 'Rolled Oats (Oatmeal)',
      'unitFa': '۶۰ گرم (۶ قاشق سرپر)',
      'unitEn': '60g Dry Oats',
    },
    {
      'nameFa': 'سیبزمینی آبپز یا تنوری',
      'nameEn': 'Baked / Boiled Sweet or White Potato',
      'unitFa': '۲۰۰ گرم (۲ عدد متوسط)',
      'unitEn': '200g Medium',
    },
    {
      'nameFa': 'کره بادامزمینی طبیعی (بدون شکر)',
      'nameEn': 'Natural Peanut Butter',
      'unitFa': '۱ قاشق غذاخوری (۱۵ گرم)',
      'unitEn': '1 Tbsp (15g)',
    },
    {
      'nameFa': 'روغن زیتون فرابکر + سالاد فصل',
      'nameEn': 'Extra Virgin Olive Oil + Green Salad',
      'unitFa': '۱ قاشق غذاخوری روی سالاد',
      'unitEn': '1 Tbsp over Salad',
    },
    {
      'nameFa': 'مغزیجات خام (بادام درختی / گردو)',
      'nameEn': 'Raw Almonds & Walnuts',
      'unitFa': '۲۰ گرم (۱۰ عدد بادام)',
      'unitEn': '20g Handful',
    },
  ];
}
