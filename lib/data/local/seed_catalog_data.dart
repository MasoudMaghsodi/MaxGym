import 'dart:convert';
import 'dart:io';

class ExerciseSeedItem {
  final String id;
  final String nameFa;
  final String nameEn;
  final String targetMuscle; // chest, back, shoulders, biceps, triceps, legs, abs, calves
  final String equipment; // barbell, dumbbell, cable, machine, bodyweight
  final String imageStartUrl;
  final String imageEndUrl;
  final List<String> contraindicatedInjuries;

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

  /// آدرس مستقیم فایل JSON شامل کل ۸۷۳ حرکت استاندارد جهانی روی CDN رایگان
  static const String global873ExercisesJsonUrl =
      'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/dist/exercises.json';

  /// مترجم هوشمند خودکار نام حرکات انگلیسی به اصطلاحات رایج باشگاهی فارسی
  static String translateExerciseNameToPersian(String enName) {
    final dictionary = <String, String>{
      'Barbell': 'هالتر',
      'Dumbbell': 'دمبل',
      'Cable': 'سیمکش',
      'Machine': 'دستگاه',
      'Smith': 'اسمیت',
      'EZ-Bar': 'هالترخم (EZ)',
      'Kettlebell': 'کتلبل',
      'Band': 'کش ورزشی',
      'Bench Press': 'پرس سینه',
      'Incline': 'بالاسینه',
      'Decline': 'زیرسینه',
      'Flyes': 'قفسه (فلای)',
      'Fly': 'فلای',
      'Push-Up': 'شنا سوئدی',
      'Pushups': 'شنا سوئدی',
      'Dip': 'دیپ (پارالل)',
      'Dips': 'دیپ (پارالل)',
      'Pullover': 'پولاور',
      'Lat Pulldown': 'لت از جلو',
      'Pulldown': 'لت',
      'Pull-Up': 'بارفیکس',
      'Pullups': 'بارفیکس',
      'Chin-Up': 'بارفیکس دست برعکس',
      'Row': 'روئینگ (زیربغل)',
      'Bent Over': 'خم',
      'Seated': 'نشسته',
      'Standing': 'ایستاده',
      'Lying': 'خوابیده',
      'One-Arm': 'تکدست',
      'Single-Arm': 'تکدست',
      'Single-Leg': 'تکپا',
      'Deadlift': 'ددلیفت',
      'Romanian': 'رومانیایی',
      'Sumo': 'سومو',
      'Shrug': 'شراگ (کول)',
      'Shoulder Press': 'پرس سرشانه',
      'Military Press': 'پرس سرشانه نظامی',
      'Arnold': 'آرنولدی',
      'Lateral Raise': 'نشر جانب',
      'Front Raise': 'نشر از جلو',
      'Rear Delt': 'سرشانه خلفی',
      'Face Pull': 'فیسپول',
      'Upright Row': 'کول هالتر/دمبل',
      'Curl': 'جلوبازو',
      'Hammer': 'چکشی',
      'Preacher': 'لاری',
      'Concentration': 'تمرکزی',
      'Spider': 'عنکبوتی',
      'Reverse': 'معکوس (ساعد)',
      'Triceps': 'پشتبازو',
      'Tricep': 'پشتبازو',
      'Pushdown': 'سیمکش ایستاده',
      'Skullcrusher': 'اسکالکراشر (خوابیده)',
      'Kickback': 'کیکبک',
      'Overhead': 'بالای سر',
      'Extension': 'اکستنشن',
      'Squat': 'اسکات',
      'Front Squat': 'اسکات از جلو',
      'Hack Squat': 'هاک پا',
      'Leg Press': 'پرس پا',
      'Lunge': 'لانج (قیچی)',
      'Split Squat': 'اسکات بلغاری',
      'Leg Extension': 'جلوپا',
      'Leg Curl': 'پشت پا',
      'Hip Thrust': 'هیپتراست (پل باسن)',
      'Glute': 'سرینی (باسن)',
      'Abductor': 'خارج ران',
      'Adductor': 'داخل ران',
      'Calf Raise': 'ساق پا',
      'Crunch': 'کرانچ شکم',
      'Sit-Up': 'دراز و نشست',
      'Leg Raise': 'زیرشکم',
      'Plank': 'پلانک',
      'Russian Twist': 'چرخش روسی (پهلو)',
      'Wide-Grip': 'دست باز',
      'Close-Grip': 'دست جمع',
      'Alternate': 'متناوب',
    };

    String translated = enName;
    dictionary.forEach((en, fa) {
      translated = translated.replaceAll(
        RegExp(en, caseSensitive: false),
        fa,
      );
    });
    return translated == enName ? 'حرکت $enName' : '$translated ($enName)';
  }

  /// نگاشت عضلات استاندارد دیتابیس جهانی ۸۷۳ حرکتی به ۸ گروه عضلانی اصلی اپ
  static String mapGlobalMuscleGroup(String rawMuscle) {
    final m = rawMuscle.toLowerCase();
    if (m.contains('chest')) return 'chest';
    if (m.contains('lats') ||
        m.contains('back') ||
        m.contains('traps') ||
        m.contains('lower_back') ||
        m.contains('middle_back')) {
      return 'back';
    }
    if (m.contains('shoulders') || m.contains('neck')) return 'shoulders';
    if (m.contains('biceps') || m.contains('forearms')) return 'biceps';
    if (m.contains('triceps')) return 'triceps';
    if (m.contains('quadriceps') ||
        m.contains('hamstrings') ||
        m.contains('glutes') ||
        m.contains('abductors') ||
        m.contains('adductors')) {
      return 'legs';
    }
    if (m.contains('calves')) return 'calves';
    if (m.contains('abdominals') || m.contains('waist')) return 'abs';
    return 'chest';
  }

  /// دانلود و تبدیل خودکار کل ۸۷۳ حرکت از GitHub در پسزمینه (فقط یکبار)
  static Future<List<ExerciseSeedItem>> fetchAll873GlobalExercises() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(global873ExercisesJsonUrl));
      final res = await req.close();
      if (res.statusCode != 200) return [];

      final jsonStr = await res.transform(utf8.decoder).join();
      final List<dynamic> decoded = jsonDecode(jsonStr);

      final List<ExerciseSeedItem> items = [];
      for (final raw in decoded) {
        final map = raw as Map<String, dynamic>;
        final id = map['id'] as String? ?? '';
        final nameEn = map['name'] as String? ?? '';
        if (id.isEmpty || nameEn.isEmpty) continue;

        final primaryMuscles =
            List<String>.from(map['primaryMuscles'] ?? const ['chest']);
        final rawMuscle =
            primaryMuscles.isNotEmpty ? primaryMuscles.first : 'chest';
        final targetMuscle = mapGlobalMuscleGroup(rawMuscle);
        final equipment = (map['equipment'] as String?) ?? 'bodyweight';

        final images = List<String>.from(map['images'] ?? const []);
        final imgStart =
            images.isNotEmpty ? '$_cdnBase/${images.first}' : '$_cdnBase/$id/0.jpg';
        final imgEnd =
            images.length > 1 ? '$_cdnBase/${images[1]}' : '$_cdnBase/$id/1.jpg';

        final List<String> injuries = [];
        final lowerName = nameEn.toLowerCase();
        if (lowerName.contains('deadlift') ||
            lowerName.contains('bent over') ||
            lowerName.contains('good morning')) {
          injuries.add('lower_back');
        }
        if (lowerName.contains('squat') ||
            lowerName.contains('lunge') ||
            lowerName.contains('leg extension')) {
          injuries.add('knee');
        }
        if (lowerName.contains('press') ||
            lowerName.contains('dip') ||
            lowerName.contains('upright')) {
          injuries.add('shoulder');
        }

        items.add(
          ExerciseSeedItem(
            id: id,
            nameFa: translateExerciseNameToPersian(nameEn),
            nameEn: nameEn,
            targetMuscle: targetMuscle,
            equipment: equipment,
            imageStartUrl: imgStart,
            imageEndUrl: imgEnd,
            contraindicatedInjuries: injuries,
          ),
        );
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  /// بانک غنی حرکات پایه آفلاین (که حتی قبل از اولین اتصال اینترنت در گوشی آماده است)
  static const List<ExerciseSeedItem> initialExercises = [
    // ================= CHEST (سینه) =================
    ExerciseSeedItem(
      id: 'Barbell_Bench_Press_-_Medium_Grip',
      nameFa: 'پرس سینه هالتر دست متوسط',
      nameEn: 'Barbell Bench Press',
      targetMuscle: 'chest',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Bench_Press_-_Medium_Grip/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Bench_Press_-_Medium_Grip/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Dumbbell_Bench_Press',
      nameFa: 'پرس سینه دمبل تخت',
      nameEn: 'Dumbbell Bench Press',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Dumbbell_Bench_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Dumbbell_Bench_Press/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Barbell_Incline_Bench_Press_-_Medium_Grip',
      nameFa: 'پرس بالاسینه هالتر',
      nameEn: 'Barbell Incline Bench Press',
      targetMuscle: 'chest',
      equipment: 'barbell',
      imageStartUrl:
          '$_cdnBase/Barbell_Incline_Bench_Press_-_Medium_Grip/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Incline_Bench_Press_-_Medium_Grip/1.jpg',
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
      id: 'Decline_Barbell_Bench_Press',
      nameFa: 'پرس زیرسینه هالتر',
      nameEn: 'Decline Barbell Bench Press',
      targetMuscle: 'chest',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Decline_Barbell_Bench_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Decline_Barbell_Bench_Press/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Decline_Dumbbell_Bench_Press',
      nameFa: 'پرس زیرسینه دمبل',
      nameEn: 'Decline Dumbbell Press',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Decline_Dumbbell_Bench_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Decline_Dumbbell_Bench_Press/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Dumbbell_Flyes',
      nameFa: 'قفسه سینه دمبل تخت (فلای)',
      nameEn: 'Dumbbell Chest Flyes',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Dumbbell_Flyes/0.jpg',
      imageEndUrl: '$_cdnBase/Dumbbell_Flyes/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Incline_Dumbbell_Flyes',
      nameFa: 'فلای بالاسینه دمبل',
      nameEn: 'Incline Dumbbell Flyes',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Incline_Dumbbell_Flyes/0.jpg',
      imageEndUrl: '$_cdnBase/Incline_Dumbbell_Flyes/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Cable_Crossover',
      nameFa: 'کراساور سیمکش ایستاده',
      nameEn: 'Cable Crossover',
      targetMuscle: 'chest',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Cable_Crossover/0.jpg',
      imageEndUrl: '$_cdnBase/Cable_Crossover/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Low_Cable_Crossover',
      nameFa: 'کراساور سیمکش از پایین (بالاسینه)',
      nameEn: 'Low Cable Crossover',
      targetMuscle: 'chest',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Low_Cable_Crossover/0.jpg',
      imageEndUrl: '$_cdnBase/Low_Cable_Crossover/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Butterfly',
      nameFa: 'پروانه دستگاه (پکدک سینه)',
      nameEn: 'Pec Deck Butterfly Machine',
      targetMuscle: 'chest',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Butterfly/0.jpg',
      imageEndUrl: '$_cdnBase/Butterfly/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Dips_-_Chest_Version',
      nameFa: 'دیپ پارالل (فرم زیرسینه)',
      nameEn: 'Chest Dips',
      targetMuscle: 'chest',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Dips_-_Chest_Version/0.jpg',
      imageEndUrl: '$_cdnBase/Dips_-_Chest_Version/1.jpg',
      contraindicatedInjuries: ['shoulder', 'wrist'],
    ),
    ExerciseSeedItem(
      id: 'Bent-Arm_Dumbbell_Pullover',
      nameFa: 'پولاور دمبل خوابیده',
      nameEn: 'Dumbbell Pullover',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Bent-Arm_Dumbbell_Pullover/0.jpg',
      imageEndUrl: '$_cdnBase/Bent-Arm_Dumbbell_Pullover/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Pushups',
      nameFa: 'شنا سوئدی کلاسیک',
      nameEn: 'Standard Push-Ups',
      targetMuscle: 'chest',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Pushups/0.jpg',
      imageEndUrl: '$_cdnBase/Pushups/1.jpg',
    ),

    // ================= BACK (زیربغل، پشت و کول) =================
    ExerciseSeedItem(
      id: 'Pullups',
      nameFa: 'بارفیکس دست باز از جلو',
      nameEn: 'Wide-Grip Pull-Ups',
      targetMuscle: 'back',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Pullups/0.jpg',
      imageEndUrl: '$_cdnBase/Pullups/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Chin-Up',
      nameFa: 'بارفیکس دست جمع برعکس',
      nameEn: 'Underhand Chin-Ups',
      targetMuscle: 'back',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Chin-Up/0.jpg',
      imageEndUrl: '$_cdnBase/Chin-Up/1.jpg',
    ),
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
      id: 'Close-Grip_Front_Lat_Pulldown',
      nameFa: 'لت سیمکش دست جمع (دسته V)',
      nameEn: 'Close-Grip V-Bar Pulldown',
      targetMuscle: 'back',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Close-Grip_Front_Lat_Pulldown/0.jpg',
      imageEndUrl: '$_cdnBase/Close-Grip_Front_Lat_Pulldown/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Underhand_Cable_Pulldowns',
      nameFa: 'لت سیمکش دست برعکس (مچ به داخل)',
      nameEn: 'Reverse-Grip Lat Pulldown',
      targetMuscle: 'back',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Underhand_Cable_Pulldowns/0.jpg',
      imageEndUrl: '$_cdnBase/Underhand_Cable_Pulldowns/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Straight-Arm_Pulldown',
      nameFa: 'پولاور سیمکش ایستاده دست صاف',
      nameEn: 'Straight-Arm Rope Pulldown',
      targetMuscle: 'back',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Straight-Arm_Pulldown/0.jpg',
      imageEndUrl: '$_cdnBase/Straight-Arm_Pulldown/1.jpg',
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
      id: 'Reverse_Grip_Bent-Over_Rows',
      nameFa: 'زیربغل هالتر خم دست برعکس (فرم دوریان یتس)',
      nameEn: 'Reverse-Grip Barbell Row',
      targetMuscle: 'back',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Reverse_Grip_Bent-Over_Rows/0.jpg',
      imageEndUrl: '$_cdnBase/Reverse_Grip_Bent-Over_Rows/1.jpg',
      contraindicatedInjuries: ['lower_back'],
    ),
    ExerciseSeedItem(
      id: 'T-Bar_Row_with_Handle',
      nameFa: 'زیربغل تیبار (T-Bar Row)',
      nameEn: 'T-Bar Row',
      targetMuscle: 'back',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/T-Bar_Row_with_Handle/0.jpg',
      imageEndUrl: '$_cdnBase/T-Bar_Row_with_Handle/1.jpg',
      contraindicatedInjuries: ['lower_back'],
    ),
    ExerciseSeedItem(
      id: 'Seated_Cable_Rows',
      nameFa: 'زیربغل قایقی سیمکش (پشت دست جمع)',
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
    ExerciseSeedItem(
      id: 'Hyperextensions_Back_Extensions',
      nameFa: 'فیله کمر روی میز (هایپراکستنشن)',
      nameEn: 'Back Hyperextensions',
      targetMuscle: 'back',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Hyperextensions_Back_Extensions/0.jpg',
      imageEndUrl: '$_cdnBase/Hyperextensions_Back_Extensions/1.jpg',
    ),

    // ================= SHOULDERS (سرشانه و کول) =================
    ExerciseSeedItem(
      id: 'Seated_Barbell_Military_Press',
      nameFa: 'پرس سرشانه هالتر از جلو نشسته',
      nameEn: 'Seated Barbell Military Press',
      targetMuscle: 'shoulders',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Seated_Barbell_Military_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Seated_Barbell_Military_Press/1.jpg',
      contraindicatedInjuries: ['shoulder', 'neck'],
    ),
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
      id: 'Arnold_Dumbbell_Press',
      nameFa: 'پرس سرشانه دمبل آرنولدی',
      nameEn: 'Arnold Dumbbell Press',
      targetMuscle: 'shoulders',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Arnold_Dumbbell_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Arnold_Dumbbell_Press/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Side_Lateral_Raise',
      nameFa: 'نشر جانب دمبل ایستاده',
      nameEn: 'Dumbbell Lateral Raise',
      targetMuscle: 'shoulders',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Side_Lateral_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Side_Lateral_Raise/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Cable_Seated_Lateral_Raise',
      nameFa: 'نشر جانب سیمکش',
      nameEn: 'Cable Lateral Raise',
      targetMuscle: 'shoulders',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Cable_Seated_Lateral_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Cable_Seated_Lateral_Raise/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Front_Dumbbell_Raise',
      nameFa: 'نشر از جلو دمبل متناوب',
      nameEn: 'Front Dumbbell Raise',
      targetMuscle: 'shoulders',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Front_Dumbbell_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Front_Dumbbell_Raise/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Seated_Bent-Over_Rear_Delt_Raise',
      nameFa: 'نشر خم دمبل (سرشانه خلفی)',
      nameEn: 'Bent-Over Rear Delt Fly',
      targetMuscle: 'shoulders',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Seated_Bent-Over_Rear_Delt_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Seated_Bent-Over_Rear_Delt_Raise/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Reverse_Machine_Flyes',
      nameFa: 'فلای معکوس دستگاه (سرشانه خلفی)',
      nameEn: 'Reverse Pec-Deck Rear Delt',
      targetMuscle: 'shoulders',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Reverse_Machine_Flyes/0.jpg',
      imageEndUrl: '$_cdnBase/Reverse_Machine_Flyes/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Face_Pull',
      nameFa: 'فیسپول سیمکش با طناب',
      nameEn: 'Cable Face Pull',
      targetMuscle: 'shoulders',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Face_Pull/0.jpg',
      imageEndUrl: '$_cdnBase/Face_Pull/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Upright_Barbell_Row',
      nameFa: 'کول هالتر ایستاده',
      nameEn: 'Barbell Upright Row',
      targetMuscle: 'shoulders',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Upright_Barbell_Row/0.jpg',
      imageEndUrl: '$_cdnBase/Upright_Barbell_Row/1.jpg',
      contraindicatedInjuries: ['shoulder', 'wrist'],
    ),
    ExerciseSeedItem(
      id: 'Barbell_Shrug',
      nameFa: 'شراگ هالتر ایستاده (کول)',
      nameEn: 'Barbell Shrugs',
      targetMuscle: 'shoulders',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Shrug/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Shrug/1.jpg',
      contraindicatedInjuries: ['neck'],
    ),
    ExerciseSeedItem(
      id: 'Dumbbell_Shrug',
      nameFa: 'شراگ دمبل ایستاده',
      nameEn: 'Dumbbell Shrugs',
      targetMuscle: 'shoulders',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Dumbbell_Shrug/0.jpg',
      imageEndUrl: '$_cdnBase/Dumbbell_Shrug/1.jpg',
    ),

    // ================= LEGS & GLUTES (پا و سرینی) =================
    ExerciseSeedItem(
      id: 'Barbell_Full_Squat',
      nameFa: 'اسکات کامل با هالتر (پشت گردن)',
      nameEn: 'Barbell Back Squat',
      targetMuscle: 'legs',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Full_Squat/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Full_Squat/1.jpg',
      contraindicatedInjuries: ['knee', 'lower_back'],
    ),
    ExerciseSeedItem(
      id: 'Front_Barbell_Squat',
      nameFa: 'اسکات هالتر از جلو (تمرکز چهارسر)',
      nameEn: 'Barbell Front Squat',
      targetMuscle: 'legs',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Front_Barbell_Squat/0.jpg',
      imageEndUrl: '$_cdnBase/Front_Barbell_Squat/1.jpg',
      contraindicatedInjuries: ['knee', 'wrist'],
    ),
    ExerciseSeedItem(
      id: 'Hack_Squat',
      nameFa: 'هاک اسکات دستگاه (هاک پا)',
      nameEn: 'Machine Hack Squat',
      targetMuscle: 'legs',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Hack_Squat/0.jpg',
      imageEndUrl: '$_cdnBase/Hack_Squat/1.jpg',
      contraindicatedInjuries: ['knee'],
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
      id: 'Dumbbell_Lunges',
      nameFa: 'لانج دمبل راه رفتنی / درجا (قیچی)',
      nameEn: 'Dumbbell Lunges',
      targetMuscle: 'legs',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Dumbbell_Lunges/0.jpg',
      imageEndUrl: '$_cdnBase/Dumbbell_Lunges/1.jpg',
      contraindicatedInjuries: ['knee'],
    ),
    ExerciseSeedItem(
      id: 'Single_Leg_Squat',
      nameFa: 'اسکات بلغاری تکپا دمبل',
      nameEn: 'Bulgarian Split Squat',
      targetMuscle: 'legs',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Single_Leg_Squat/0.jpg',
      imageEndUrl: '$_cdnBase/Single_Leg_Squat/1.jpg',
      contraindicatedInjuries: ['knee'],
    ),
    ExerciseSeedItem(
      id: 'Leg_Extensions',
      nameFa: 'جلوپا دستگاه نشسته',
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
      id: 'Seated_Leg_Curl',
      nameFa: 'پشت پا نشسته دستگاه',
      nameEn: 'Seated Leg Curl',
      targetMuscle: 'legs',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Seated_Leg_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Seated_Leg_Curl/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Romanian_Deadlift',
      nameFa: 'ددلیفت رومانیایی هالتر/دمبل (پشت پا)',
      nameEn: 'Romanian Deadlift (RDL)',
      targetMuscle: 'legs',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Romanian_Deadlift/0.jpg',
      imageEndUrl: '$_cdnBase/Romanian_Deadlift/1.jpg',
      contraindicatedInjuries: ['lower_back'],
    ),
    ExerciseSeedItem(
      id: 'Barbell_Glute_Bridge',
      nameFa: 'هیپتراست هالتر (پل باسن)',
      nameEn: 'Barbell Hip Thrust / Glute Bridge',
      targetMuscle: 'legs',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Barbell_Glute_Bridge/0.jpg',
      imageEndUrl: '$_cdnBase/Barbell_Glute_Bridge/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Thigh_Abductor',
      nameFa: 'خارج ران دستگاه نشسته',
      nameEn: 'Seated Hip Abductor',
      targetMuscle: 'legs',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Thigh_Abductor/0.jpg',
      imageEndUrl: '$_cdnBase/Thigh_Abductor/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Thigh_Adductor',
      nameFa: 'داخل ران دستگاه نشسته',
      nameEn: 'Seated Hip Adductor',
      targetMuscle: 'legs',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Thigh_Adductor/0.jpg',
      imageEndUrl: '$_cdnBase/Thigh_Adductor/1.jpg',
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
    ExerciseSeedItem(
      id: 'Seated_Calf_Raise',
      nameFa: 'ساق پا نشسته دستگاه',
      nameEn: 'Seated Calf Raise',
      targetMuscle: 'calves',
      equipment: 'machine',
      imageStartUrl: '$_cdnBase/Seated_Calf_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Seated_Calf_Raise/1.jpg',
    ),

    // ================= BICEPS & FOREARMS (جلوبازو و ساعد) =================
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
      id: 'EZ-Bar_Curl',
      nameFa: 'جلوبازو هالتر خم (EZ) ایستاده',
      nameEn: 'EZ-Bar Bicep Curl',
      targetMuscle: 'biceps',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/EZ-Bar_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/EZ-Bar_Curl/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Dumbbell_Bicep_Curl',
      nameFa: 'جلوبازو دمبل جفت/متناوب ایستاده',
      nameEn: 'Standing Dumbbell Bicep Curl',
      targetMuscle: 'biceps',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Dumbbell_Bicep_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Dumbbell_Bicep_Curl/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Incline_Dumbbell_Curl',
      nameFa: 'جلوبازو دمبل روی میز شیبدار',
      nameEn: 'Incline Dumbbell Curl',
      targetMuscle: 'biceps',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Incline_Dumbbell_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Incline_Dumbbell_Curl/1.jpg',
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
      id: 'Preacher_Curl',
      nameFa: 'جلوبازو لاری با هالتر خم / دمبل',
      nameEn: 'Preacher Curl',
      targetMuscle: 'biceps',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Preacher_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Preacher_Curl/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Concentration_Curls',
      nameFa: 'جلوبازو دمبل تمرکزی تکدست نشسته',
      nameEn: 'Concentration Curl',
      targetMuscle: 'biceps',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Concentration_Curls/0.jpg',
      imageEndUrl: '$_cdnBase/Concentration_Curls/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Standing_Biceps_Cable_Curl',
      nameFa: 'جلوبازو سیمکش ایستاده',
      nameEn: 'Standing Cable Bicep Curl',
      targetMuscle: 'biceps',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Standing_Biceps_Cable_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Standing_Biceps_Cable_Curl/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Reverse_Barbell_Curl',
      nameFa: 'ساعد هالتر ایستاده (جلوبازو دست برعکس)',
      nameEn: 'Reverse Barbell Curl',
      targetMuscle: 'biceps',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Reverse_Barbell_Curl/0.jpg',
      imageEndUrl: '$_cdnBase/Reverse_Barbell_Curl/1.jpg',
    ),

    // ================= TRICEPS (پشتبازو) =================
    ExerciseSeedItem(
      id: 'Triceps_Pushdown',
      nameFa: 'پشتبازو سیمکش با دسته صاف',
      nameEn: 'Cable Triceps Pushdown',
      targetMuscle: 'triceps',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Triceps_Pushdown/0.jpg',
      imageEndUrl: '$_cdnBase/Triceps_Pushdown/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Triceps_Pushdown_-_Rope_Attachment',
      nameFa: 'پشتبازو سیمکش با طناب',
      nameEn: 'Rope Triceps Pushdown',
      targetMuscle: 'triceps',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Triceps_Pushdown_-_Rope_Attachment/0.jpg',
      imageEndUrl: '$_cdnBase/Triceps_Pushdown_-_Rope_Attachment/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'EZ-Bar_Skullcrusher',
      nameFa: 'پشتبازو هالتر خم خوابیده (اسکالکراشر)',
      nameEn: 'EZ-Bar Skullcrusher',
      targetMuscle: 'triceps',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/EZ-Bar_Skullcrusher/0.jpg',
      imageEndUrl: '$_cdnBase/EZ-Bar_Skullcrusher/1.jpg',
      contraindicatedInjuries: ['wrist', 'shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Close-Grip_Barbell_Bench_Press',
      nameFa: 'پرس سینه هالتر دست جمع (پشتبازو پرسی)',
      nameEn: 'Close-Grip Bench Press',
      targetMuscle: 'triceps',
      equipment: 'barbell',
      imageStartUrl: '$_cdnBase/Close-Grip_Barbell_Bench_Press/0.jpg',
      imageEndUrl: '$_cdnBase/Close-Grip_Barbell_Bench_Press/1.jpg',
      contraindicatedInjuries: ['wrist'],
    ),
    ExerciseSeedItem(
      id: 'Standing_Dumbbell_Triceps_Extension',
      nameFa: 'پشتبازو دمبل جفت دست بالای سر',
      nameEn: 'Overhead Dumbbell Triceps Extension',
      targetMuscle: 'triceps',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Standing_Dumbbell_Triceps_Extension/0.jpg',
      imageEndUrl: '$_cdnBase/Standing_Dumbbell_Triceps_Extension/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Tricep_Dumbbell_Kickback',
      nameFa: 'پشتبازو دمبل تکدست خم (کیکبک)',
      nameEn: 'Dumbbell Tricep Kickback',
      targetMuscle: 'triceps',
      equipment: 'dumbbell',
      imageStartUrl: '$_cdnBase/Tricep_Dumbbell_Kickback/0.jpg',
      imageEndUrl: '$_cdnBase/Tricep_Dumbbell_Kickback/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Bench_Dips',
      nameFa: 'دیپ پشتبازو بین دو میز',
      nameEn: 'Bench Tricep Dips',
      targetMuscle: 'triceps',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Bench_Dips/0.jpg',
      imageEndUrl: '$_cdnBase/Bench_Dips/1.jpg',
      contraindicatedInjuries: ['shoulder'],
    ),

    // ================= ABS & CORE (شکم و میانتنه) =================
    ExerciseSeedItem(
      id: 'Cable_Crunch',
      nameFa: 'کرانچ شکم سیمکش نشسته روی زانو',
      nameEn: 'Kneeling Cable Crunch',
      targetMuscle: 'abs',
      equipment: 'cable',
      imageStartUrl: '$_cdnBase/Cable_Crunch/0.jpg',
      imageEndUrl: '$_cdnBase/Cable_Crunch/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Crunches',
      nameFa: 'کرانچ شکم خوابیده روی زمین',
      nameEn: 'Floor Crunches',
      targetMuscle: 'abs',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Crunches/0.jpg',
      imageEndUrl: '$_cdnBase/Crunches/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Hanging_Leg_Raise',
      nameFa: 'زیرشکم آویزان از بارفیکس',
      nameEn: 'Hanging Leg Raise',
      targetMuscle: 'abs',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Hanging_Leg_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Hanging_Leg_Raise/1.jpg',
      contraindicatedInjuries: ['lower_back', 'shoulder'],
    ),
    ExerciseSeedItem(
      id: 'Flat_Bench_Lying_Leg_Raise',
      nameFa: 'زیرشکم خوابیده روی نیمکت',
      nameEn: 'Lying Bench Leg Raise',
      targetMuscle: 'abs',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Flat_Bench_Lying_Leg_Raise/0.jpg',
      imageEndUrl: '$_cdnBase/Flat_Bench_Lying_Leg_Raise/1.jpg',
    ),
    ExerciseSeedItem(
      id: 'Russian_Twist',
      nameFa: 'چرخش روسی با صفحه/دمبل (عضلات مورب و پهلو)',
      nameEn: 'Russian Twist',
      targetMuscle: 'abs',
      equipment: 'bodyweight',
      imageStartUrl: '$_cdnBase/Russian_Twist/0.jpg',
      imageEndUrl: '$_cdnBase/Russian_Twist/1.jpg',
      contraindicatedInjuries: ['lower_back'],
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

  /// بانک جامع ۳۰ مکمل، ویتامین، مینرال و آمینواسید تخصصی ورزشکاران
  static const List<Map<String, String>> supplementCatalog = [
    // --- پروتئینها و گینرها ---
    {
      'id': 'whey_protein',
      'nameFa': 'پروتئین وی کنسانتره (Whey Protein)',
      'nameEn': 'Whey Protein Concentrate',
      'defaultDosageFa': '۱ اسکوپ (۳۰ گرم)',
      'defaultDosageEn': '1 Scoop (30g)',
      'defaultTimingFa': 'بلافاصله بعد از تمرین با آب',
      'defaultTimingEn': 'Immediately Post-Workout',
    },
    {
      'id': 'iso_whey',
      'nameFa': 'پروتئین وی ایزوله (ISO Whey - بدون قند و چربی)',
      'nameEn': 'Hydrolyzed / Isolate Whey Protein',
      'defaultDosageFa': '۱ اسکوپ (۳۰ گرم)',
      'defaultDosageEn': '1 Scoop (30g)',
      'defaultTimingFa': 'بلافاصله بعد از تمرین یا صبح ناشتا',
      'defaultTimingEn': 'Post-Workout or Fasted Morning',
    },
    {
      'id': 'casein_protein',
      'nameFa': 'پروتئین کازئین دیرجذب (Casein)',
      'nameEn': 'Micellar Casein Protein',
      'defaultDosageFa': '۱ اسکوپ (۳۰ گرم)',
      'defaultDosageEn': '1 Scoop (30g)',
      'defaultTimingFa': '۳۰ دقیقه قبل از خواب شبانه',
      'defaultTimingEn': '30 Mins Before Bed',
    },
    {
      'id': 'mass_gainer',
      'nameFa': 'مس گینر افزایش وزن و حجم (Mass Gainer)',
      'nameEn': 'High-Calorie Mass Gainer',
      'defaultDosageFa': '۱ تا ۲ اسکوپ (۱۰۰ گرم)',
      'defaultDosageEn': '1-2 Scoops (100g)',
      'defaultTimingFa': 'بعد از تمرین و میانوعده عصر',
      'defaultTimingEn': 'Post-Workout & Afternoon Snack',
    },
    {
      'id': 'beef_egg_protein',
      'nameFa': 'پروتئین بیف یا آلبومین (سفیده تخممرغ)',
      'nameEn': 'Beef / Egg White Albumin Protein',
      'defaultDosageFa': '۱ اسکوپ (۳۰ گرم)',
      'defaultDosageEn': '1 Scoop (30g)',
      'defaultTimingFa': 'بعد از تمرین (بدون لاکتوز)',
      'defaultTimingEn': 'Post-Workout (Lactose-Free)',
    },

    // --- افزایش قدرت، پمپ و استقامت ---
    {
      'id': 'creatine',
      'nameFa': 'کراتین مونوهیدرات میکرونایزد (Creatine)',
      'nameEn': 'Micronized Creatine Monohydrate',
      'defaultDosageFa': '۵ گرم (۱ اسکوپ)',
      'defaultDosageEn': '5 Grams (1 Scoop)',
      'defaultTimingFa': 'بعد از تمرین همراه آب فراوان',
      'defaultTimingEn': 'Post-Workout with water',
    },
    {
      'id': 'beta_alanine',
      'nameFa': 'بتا آلانین (Beta-Alanine - ضد اسیدی شدن عضله)',
      'nameEn': 'Beta-Alanine',
      'defaultDosageFa': '۳ تا ۴ گرم',
      'defaultDosageEn': '3-4 Grams',
      'defaultTimingFa': '۲۰ دقیقه قبل از شروع تمرین',
      'defaultTimingEn': '20 Mins Pre-Workout',
    },
    {
      'id': 'citrulline_malate',
      'nameFa': 'سیترولین مالات (پمپ خون و رگزایی)',
      'nameEn': 'L-Citrulline Malate 2:1',
      'defaultDosageFa': '۶ تا ۸ گرم',
      'defaultDosageEn': '6-8 Grams',
      'defaultTimingFa': '۳۰ دقیقه قبل از تمرین',
      'defaultTimingEn': '30 Mins Pre-Workout',
    },
    {
      'id': 'arginine',
      'nameFa': 'ال-آرژنین (L-Arginine / AAKG)',
      'nameEn': 'L-Arginine / AAKG',
      'defaultDosageFa': '۳ گرم یا ۲ عدد قرص ۱۰۰۰ میلیگرم',
      'defaultDosageEn': '3g or 2x1000mg Tabs',
      'defaultTimingFa': 'قبل از تمرین یا قبل از خواب',
      'defaultTimingEn': 'Pre-Workout or Before Bed',
    },
    {
      'id': 'caffeine_pre',
      'nameFa': 'کافئین / پمپ انرژیزا (Pre-Workout / Caffeine)',
      'nameEn': 'Pre-Workout / Caffeine 200mg',
      'defaultDosageFa': '۱ اسکوپ پمپ یا ۱ قرص ۲۰۰ میلیگرم',
      'defaultDosageEn': '1 Serving / 200mg Tab',
      'defaultTimingFa': '۳۰ دقیقه قبل از تمرین',
      'defaultTimingEn': '30 Mins Pre-Workout',
    },

    // --- آمینواسیدها و ریکاوری ---
    {
      'id': 'bcaa_eaa',
      'nameFa': 'بیسیایای / آمینو ضروری (BCAA / EAA)',
      'nameEn': 'BCAA 2:1:1 / Full Spectrum EAA',
      'defaultDosageFa': '۱ اسکوپ (۱۰ گرم)',
      'defaultDosageEn': '1 Scoop (10g)',
      'defaultTimingFa': 'حین تمرین محلول در بطری آب',
      'defaultTimingEn': 'Intra-Workout',
    },
    {
      'id': 'glutamine',
      'nameFa': 'ال-گلوتامین (ریکاوری و ایمنی - L-Glutamine)',
      'nameEn': 'L-Glutamine',
      'defaultDosageFa': '۵ گرم',
      'defaultDosageEn': '5 Grams',
      'defaultTimingFa': 'قبل از خواب و بعد از تمرین',
      'defaultTimingEn': 'Post-Workout & Before Bed',
    },
    {
      'id': 'hmb',
      'nameFa': 'اچامبی ضد کاتابولیسم (HMB 1000)',
      'nameEn': 'HMB (Beta-Hydroxy Beta-Methylbutyrate)',
      'defaultDosageFa': '۳ گرم (۳ عدد کپسول ۱۰۰۰)',
      'defaultDosageEn': '3 Capsules (3000mg total)',
      'defaultTimingFa': 'همراه صبحانه، قبل تمرین و شب',
      'defaultTimingEn': 'Split with main meals',
    },

    // --- چربیسوزها و متابولیسم ---
    {
      'id': 'l_carnitine',
      'nameFa': 'ال-کارنیتین مایع یا قرص (L-Carnitine)',
      'nameEn': 'L-Carnitine Tartrate (2000mg)',
      'defaultDosageFa': '۲۰۰۰ میلیگرم (۱ شات یا ۲ قرص)',
      'defaultDosageEn': '2000mg Serving',
      'defaultTimingFa': '۳۰ دقیقه قبل از هوازی یا تمرین',
      'defaultTimingEn': '30 Mins Pre-Cardio/Workout',
    },
    {
      'id': 'cla',
      'nameFa': 'سیالای (چربیسوز غیرمحرک - CLA)',
      'nameEn': 'CLA (Conjugated Linoleic Acid)',
      'defaultDosageFa': '۱ عدد سافتژل ۱۰۰۰ میلیگرم',
      'defaultDosageEn': '1 Softgel (1000mg)',
      'defaultTimingFa': 'همراه وعده ناهار و شام',
      'defaultTimingEn': 'With Lunch & Dinner',
    },

    // --- ویتامینها، مینرالها و سلامت عمومی (Vitamins & Minerals) ---
    {
      'id': 'multivitamin',
      'nameFa': 'مولتیویتامین مینرال تخصصی ورزشی',
      'nameEn': 'Daily Sports Multivitamin',
      'defaultDosageFa': '۱ عدد قرص کامل',
      'defaultDosageEn': '1 Tablet',
      'defaultTimingFa': 'همراه وعده صبحانه',
      'defaultTimingEn': 'With Breakfast',
    },
    {
      'id': 'omega3',
      'nameFa': 'امگا ۳ (روغن ماهی با EPA/DHA بالا)',
      'nameEn': 'Omega-3 Fish Oil (1000mg)',
      'defaultDosageFa': '۲ عدد سافتژل',
      'defaultDosageEn': '2 Softgels',
      'defaultTimingFa': 'همراه ناهار و شام',
      'defaultTimingEn': 'With Lunch & Dinner',
    },
    {
      'id': 'vit_d3',
      'nameFa': 'ویتامین D3 + K2 (تقویت تستوسترون و استخوان)',
      'nameEn': 'Vitamin D3 (2000-5000 IU) + K2',
      'defaultDosageFa': '۱ عدد پرل ۲۰۰۰ یا ۵۰۰۰ واحد',
      'defaultDosageEn': '1 Softgel',
      'defaultTimingFa': 'همراه وعده حاوی چربی سالم (ناهار)',
      'defaultTimingEn': 'With a fat-containing meal',
    },
    {
      'id': 'vit_c',
      'nameFa': 'ویتامین C (آنتیاکسیدان و کاهش کورتیزول)',
      'nameEn': 'Vitamin C (1000mg)',
      'defaultDosageFa': '۵۰۰ تا ۱۰۰۰ میلیگرم',
      'defaultDosageEn': '500-1000mg',
      'defaultTimingFa': 'همراه صبحانه یا ۲ ساعت بعد از تمرین',
      'defaultTimingEn': 'Morning or 2h Post-Workout',
    },
    {
      'id': 'vit_b_complex',
      'nameFa': 'ویتامین ب-کمپلکس + ب۱۲ (متابولیسم و انرژی)',
      'nameEn': 'Vitamin B-Complex + B12',
      'defaultDosageFa': '۱ عدد قرص',
      'defaultDosageEn': '1 Tablet',
      'defaultTimingFa': 'همراه وعده صبحانه',
      'defaultTimingEn': 'With Breakfast',
    },
    {
      'id': 'vit_e',
      'nameFa': 'ویتامین E (ریکاوری سلولی - ۴۰۰ واحد)',
      'nameEn': 'Vitamin E (400 IU)',
      'defaultDosageFa': '۱ عدد پرل ۴۰۰ واحد',
      'defaultDosageEn': '1 Softgel (400 IU)',
      'defaultTimingFa': 'همراه وعده ناهار (یک روز درمیان)',
      'defaultTimingEn': 'Every other day with Lunch',
    },
    {
      'id': 'zinc_plus',
      'nameFa': 'زینک پلاس / زینک پیکولینات (Zinc)',
      'nameEn': 'Zinc Picolinate / Gluconate (30mg)',
      'defaultDosageFa': '۱ عدد کپسول ۱۵ تا ۳۰ میلیگرم',
      'defaultDosageEn': '1 Capsule (15-30mg)',
      'defaultTimingFa': 'همراه شام',
      'defaultTimingEn': 'With Dinner',
    },
    {
      'id': 'magnesium',
      'nameFa': 'منیزیم سیترات / گلیسینات (ضد گرفتگی عضلات)',
      'nameEn': 'Magnesium Citrate / Bisglycinate (400mg)',
      'defaultDosageFa': '۱ تا ۲ عدد قرص (۴۰۰ میلیگرم)',
      'defaultDosageEn': '400mg Elemental',
      'defaultTimingFa': '۴۵ دقیقه قبل از خواب شبانه',
      'defaultTimingEn': '45 Mins Before Bed',
    },
    {
      'id': 'zma',
      'nameFa': 'زد ام ای (ترکیب زینک، منیزیم و B6 - ZMA)',
      'nameEn': 'ZMA (Zinc, Magnesium, B6)',
      'defaultDosageFa': '۲ تا ۳ عدد کپسول',
      'defaultDosageEn': '2-3 Capsules',
      'defaultTimingFa': '۳۰ دقیقه قبل از خواب با معده نیمهخالی',
      'defaultTimingEn': '30 Mins Before Bed',
    },
    {
      'id': 'calcium_d',
      'nameFa': 'کلسیم سیترات + منیزیم + زینک',
      'nameEn': 'Calcium Citrate + D3',
      'defaultDosageFa': '۱ عدد قرص',
      'defaultDosageEn': '1 Tablet',
      'defaultTimingFa': 'همراه وعده ناهار (جدا از آهن)',
      'defaultTimingEn': 'With Lunch',
    },
    {
      'id': 'iron_folic',
      'nameFa': 'آهن کیلیت (فروگلوبین / فرفولیک)',
      'nameEn': 'Gentle Iron Bisglycinate + Folic Acid',
      'defaultDosageFa': '۱ عدد کپسول',
      'defaultDosageEn': '1 Capsule',
      'defaultTimingFa': 'همراه ویتامین C و با فاصله از چای/لبنیات',
      'defaultTimingEn': 'Away from dairy/caffeine',
    },
    {
      'id': 'glucosamine',
      'nameFa': 'گلوکزآمین، کندروئیتین و MSM (مفاصل و غضروف)',
      'nameEn': 'Glucosamine + Chondroitin + MSM',
      'defaultDosageFa': '۲ عدد قرص در روز',
      'defaultDosageEn': '2 Tablets Daily',
      'defaultTimingFa': 'همراه وعدههای اصلی غذا',
      'defaultTimingEn': 'With Main Meals',
    },
    {
      'id': 'ashwagandha',
      'nameFa': 'آشواگاندا (کاهش استرس و کورتیزول - KSM-66)',
      'nameEn': 'Ashwagandha Root Extract (600mg)',
      'defaultDosageFa': '۶۰۰ میلیگرم (۱ کپسول)',
      'defaultDosageEn': '600mg Capsule',
      'defaultTimingFa': 'همراه شام یا قبل از خواب',
      'defaultTimingEn': 'Evening / Before Bed',
    },
    {
      'id': 'melatonin',
      'nameFa': 'ملاتونین (تنظیم خواب عمیق و ریکاوری)',
      'nameEn': 'Melatonin (3mg)',
      'defaultDosageFa': '۱ عدد قرص زیرزبانی ۳ میلیگرم',
      'defaultDosageEn': '3mg Tablet',
      'defaultTimingFa': '۳۰ دقیقه قبل از خاموشی و خواب',
      'defaultTimingEn': '30 Mins Before Sleep',
    },
    {
      'id': 'chromium',
      'nameFa': 'کرومیوم پیکولینات (کنترل قند و اشتها)',
      'nameEn': 'Chromium Picolinate (200mcg)',
      'defaultDosageFa': '۱ عدد قرص ۲۰۰ میکروگرم',
      'defaultDosageEn': '1 Tablet (200mcg)',
      'defaultTimingFa': 'قبل از وعده اصلی کربوهیدراتی',
      'defaultTimingEn': 'Before High-Carb Meal',
    },
  ];

  /// بانک جامع ۴۰ ماده غذایی پرکاربرد (ایرانی و بینالمللی) برای ساخت فوقسریع رژیم
  static const List<Map<String, String>> quickFoodCatalog = [
    // --- منابع پروتئین حیوانی و گیاهی ---
    {
      'nameFa': 'سینه مرغ گریل یا آبپز (بدون پوست)',
      'nameEn': 'Grilled Skinless Chicken Breast',
      'unitFa': '۱۵۰ گرم پخته (۱.۵ کف دست)',
      'unitEn': '150g Cooked (1.5 Palms)',
    },
    {
      'nameFa': 'فیله بوقلمون کمچرب گریل',
      'nameEn': 'Grilled Lean Turkey Breast',
      'unitFa': '۱۵۰ گرم پخته',
      'unitEn': '150g Cooked',
    },
    {
      'nameFa': 'سفیده تخممرغ آبپز',
      'nameEn': 'Boiled Egg Whites',
      'unitFa': '۵ عدد سفیده + ۱ زرده کامل',
      'unitEn': '5 Whites + 1 Whole Egg',
    },
    {
      'nameFa': 'تخممرغ کامل (املت با روغن زیتون/اسپری)',
      'nameEn': 'Whole Eggs (Omelette)',
      'unitFa': '۳ عدد تخممرغ کامل',
      'unitEn': '3 Whole Eggs',
    },
    {
      'nameFa': 'فیله ماهی سفید / تیلاپیا / قزلآلا تنوری',
      'nameEn': 'Baked White Fish / Trout Fillet',
      'unitFa': '۱۸۰ گرم پخته',
      'unitEn': '180g Fillet',
    },
    {
      'nameFa': 'فیله ماهی سالمون (غنی از امگا ۳)',
      'nameEn': 'Grilled Atlantic Salmon',
      'unitFa': '۱۵۰ گرم',
      'unitEn': '150g Fillet',
    },
    {
      'nameFa': 'کنسرو تن ماهی در آبنمک (یا کاملاً روغنگیری شده)',
      'nameEn': 'Canned Tuna in Water (Drained)',
      'unitFa': '۱ قوطی کامل (۱۲۰ گرم خالص)',
      'unitEn': '1 Can (120g Drained)',
    },
    {
      'nameFa': 'گوشت قرمز لخم (استیک فیله گوساله / چرخکرده بدون چربی)',
      'nameEn': 'Extra-Lean Beef Steak / Mince',
      'unitFa': '۱۲۰ گرم پخته',
      'unitEn': '120g Cooked',
    },
    {
      'nameFa': 'کباب برگ یا چنجه گوساله (بدون چربی اضافه)',
      'nameEn': 'Persian Lean Beef Filet Kebab (Barg)',
      'unitFa': '۱ سیخ استاندارد (۱۴۰ گرم)',
      'unitEn': '1 Skewer (140g)',
    },
    {
      'nameFa': 'جوجهکباب زعفرانی (سینه مرغ بدون کره)',
      'nameEn': 'Saffron Grilled Chicken Kebab (Joojeh)',
      'unitFa': '۱ سیخ کامل (۱۸۰ گرم)',
      'unitEn': '1 Skewer (180g)',
    },
    {
      'nameFa': 'میگو بخارپز یا گریل',
      'nameEn': 'Grilled / Steamed Shrimp',
      'unitFa': '۱۶۰ گرم',
      'unitEn': '160g Cooked',
    },
    {
      'nameFa': 'ماست یونانی پروتئینی کمچرب (یا ماست ایسلندی)',
      'nameEn': 'Low-Fat Greek / Icelandic Skyr Yogurt',
      'unitFa': '۱ کاسه متوسط (۱۵۰ گرم)',
      'unitEn': '150g Cup',
    },
    {
      'nameFa': 'پنیر کاتیج یا پنیر سفید کمچرب و کمنمک',
      'nameEn': 'Low-Fat Cottage / Feta Cheese',
      'unitFa': '۴۵ گرم (۱.۵ قوطی کبریت)',
      'unitEn': '45g Serving',
    },
    {
      'nameFa': 'کشک پاستوریزه کمنمک (منبع عالی پروتئین کازئین)',
      'nameEn': 'Pasteurized Liquid Whey (Kashk)',
      'unitFa': '۳ قاشق غذاخوری',
      'unitEn': '3 Tbsp',
    },

    // --- منابع کربوهیدرات پیچیده و انرژی ---
    {
      'nameFa': 'برنج سفید ایرانی کته یا آبکش (بدون روغن)',
      'nameEn': 'Steamed White Basmati Rice',
      'unitFa': '۸ تا ۱۰ قاشق غذاخوری (۱۵۰ گرم پخته)',
      'unitEn': '150g Cooked (8-10 Tbsp)',
    },
    {
      'nameFa': 'برنج قهوهای یا مخلوط برنج و عدس (عدسپلو رژیمی)',
      'nameEn': 'Steamed Brown Rice / Lentil Rice',
      'unitFa': '۱۰ قاشق غذاخوری (۱۶۰ گرم)',
      'unitEn': '160g Cooked',
    },
    {
      'nameFa': 'جو دوسر پرک (اوتمیل با آب یا شیر کمچرب)',
      'nameEn': 'Rolled Oats (Oatmeal)',
      'unitFa': '۶۰ گرم خشک (۶ قاشق غذاخوری سرپر)',
      'unitEn': '60g Dry Oats',
    },
    {
      'nameFa': 'سیبزمینی آبپز یا تنوری',
      'nameEn': 'Boiled / Baked White Potato',
      'unitFa': '۲۰۰ گرم (۲ عدد متوسط)',
      'unitEn': '200g (2 Medium)',
    },
    {
      'nameFa': 'سیبزمینی شیرین تنوری (Sweet Potato)',
      'nameEn': 'Baked Sweet Potato',
      'unitFa': '۱۸۰ گرم',
      'unitEn': '180g',
    },
    {
      'nameFa': 'ماکارونی یا پاستا سبوسدار (پخته آبکش)',
      'nameEn': 'Whole-Wheat Pasta (Cooked)',
      'unitFa': '۱ لیوان دستهدار (۱۵۰ گرم پخته)',
      'unitEn': '150g Cooked (1 Cup)',
    },
    {
      'nameFa': 'نان سنگک سنتی یا نان تست جو سبوسدار',
      'nameEn': 'Whole-Grain Sangak / Rye Toast Bread',
      'unitFa': '۲ کف دست سنگک (یا ۲ ورق تست پروتئینی)',
      'unitEn': '2 Slices (60g)',
    },
    {
      'nameFa': 'خوراک عدسی کمنمک با آبلیمو',
      'nameEn': 'Warm Green Lentil Soup (Adasi)',
      'unitFa': '۱ کاسه متوسط (۲۰۰ گرم)',
      'unitEn': '1 Medium Bowl (200g)',
    },
    {
      'nameFa': 'خوراک لوبیا چیتی پخته کمروغن',
      'nameEn': 'Cooked Pinto Beans',
      'unitFa': '۱ کاسه کوچک (۱۵۰ گرم)',
      'unitEn': '150g Bowl',
    },
    {
      'nameFa': 'کینوا پخته (Quinoa)',
      'nameEn': 'Cooked Quinoa',
      'unitFa': '۱۲۰ گرم پخته (۶ قاشق غذاخوری)',
      'unitEn': '120g Cooked',
    },
    {
      'nameFa': 'رایسکیک (کیک برنجی رژیمی بدون نمک)',
      'nameEn': 'Plain Brown Rice Cakes',
      'unitFa': '۳ عدد ورق رایسکیک',
      'unitEn': '3 Rice Cakes',
    },

    // --- میوهها، سبزیجات و قبل تمرین ---
    {
      'nameFa': 'موز متوسط (عالی برای قبل و بعد از تمرین)',
      'nameEn': 'Medium Ripe Banana',
      'unitFa': '۱ عدد متوسط',
      'unitEn': '1 Medium Banana',
    },
    {
      'nameFa': 'سیب سبز یا قرمز با پوست',
      'nameEn': 'Fresh Green / Red Apple',
      'unitFa': '۱ عدد متوسط',
      'unitEn': '1 Medium Apple',
    },
    {
      'nameFa': 'خرما (جهت تامین گلیکوژن سریع)',
      'nameEn': 'Medjool / Mozafati Dates',
      'unitFa': '۲ تا ۳ عدد خرما همراه قهوه',
      'unitEn': '2-3 Dates',
    },
    {
      'nameFa': 'بشقاب سبزیجات بخارپز (بروکلی، قارچ، کدو، هویج)',
      'nameEn': 'Steamed Broccoli, Mushrooms & Zucchini',
      'unitFa': '۱ بشقاب آزاد (۲۰۰ گرم)',
      'unitEn': '200g Free Veggies',
    },
    {
      'nameFa': 'سالاد کاهو، خیار، گوجهفرنگی و کلم بنفش (بدون سس مایونز)',
      'nameEn': 'Fresh Green Salad with Lemon Juice',
      'unitFa': '۱ کاسه بزرگ همراه وعده اصلی',
      'unitEn': '1 Large Bowl',
    },

    // --- چربیهای سالم و مغزیجات ---
    {
      'nameFa': 'کره بادامزمینی ۱۰۰٪ طبیعی (بدون شکر افزوده)',
      'nameEn': '100% Natural Peanut Butter',
      'unitFa': '۱ قاشق غذاخوری (۱۵ گرم)',
      'unitEn': '1 Tbsp (15g)',
    },
    {
      'nameFa': 'روغن زیتون فرابکر (اضافه شده روی سالاد یا برنج)',
      'nameEn': 'Extra Virgin Olive Oil',
      'unitFa': '۱ قاشق غذاخوری (۱۰ تا ۱۵ میلیلیتر)',
      'unitEn': '1 Tbsp (12ml)',
    },
    {
      'nameFa': 'بادام درختی خام (بدون نمک)',
      'nameEn': 'Raw Unsalted Almonds',
      'unitFa': '۱۰ تا ۱۲ عدد (۱۵ گرم)',
      'unitEn': '10-12 Almonds (15g)',
    },
    {
      'nameFa': 'مغز گردو تازه',
      'nameEn': 'Raw Walnut Halves',
      'unitFa': '۲ تا ۳ عدد گردوی کامل',
      'unitEn': '2-3 Whole Walnuts',
    },
    {
      'nameFa': 'آووکادو تازه',
      'nameEn': 'Fresh Avocado',
      'unitFa': 'نصف یک عدد آووکادو (۷۰ گرم)',
      'unitEn': 'Half Avocado (70g)',
    },
    {
      'nameFa': 'دانه چیا یا تخم کتان آسیابشده',
      'nameEn': 'Chia Seeds / Ground Flaxseeds',
      'unitFa': '۱ قاشق غذاخوری داخل اوتمیل یا ماست',
      'unitEn': '1 Tbsp (10g)',
    },
    {
      'nameFa': 'شکلات تلخ بالای ۸۵٪ + قهوه اسپرسو دبل',
      'nameEn': '85% Dark Chocolate + Double Espresso',
      'unitFa': '۱ مربع کوچک (۱۰ گرم) + ۱ شات اسپرسو',
      'unitEn': '10g Square + Espresso',
    },
    {
      'nameFa': 'کره بادام زمینی طبیعی بدون شکر',
      'nameEn': 'Natural Peanut Butter (No Sugar)',
      'unitFa': '۱ قاشق غذاخوری (۱۵ گرم)',
      'unitEn': '1 Tbsp (15g)',
    },
    {
      'nameFa': 'خرما پیارم یا مضافتی',
      'nameEn': 'Fresh Medjool/Piarom Dates',
      'unitFa': '۲ تا ۳ عدد متوسط',
      'unitEn': '2-3 Medium Dates',
    },
    {
      'nameFa': 'سیب‌زمینی شیرین آبپز یا تنوری',
      'nameEn': 'Baked or Boiled Sweet Potato',
      'unitFa': '۱ عدد متوسط (۱۵۰ گرم)',
      'unitEn': '1 Medium (150g)',
    },
  ];
}