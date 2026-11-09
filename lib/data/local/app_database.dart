import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'database_models.dart';
import 'seed_catalog_data.dart';

final appDatabaseProvider = Provider<LocalAppDatabase>((ref) {
  throw UnimplementedError('LocalAppDatabase must be initialized in main.dart');
});

enum SyncStatus { synced, pendingInsert, pendingUpdate, pendingDelete }

class AthleteEntity {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String accessCode; // کد ۶ رقمی اختصاصی ورود ورزشکار به پرتال شاگرد
  final int streakDays;
  final String gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final String fitnessGoal;
  final List<String> injuryTags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  const AthleteEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email = '',
    this.accessCode = '',
    this.streakDays = 1,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.fitnessGoal,
    required this.injuryTags,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = 'pending_insert',
  });

  String get fullName => '$firstName $lastName'.trim();

  /// بررسی اینکه آیا تمام اطلاعات ضروری ورزشکار (نام، نام خانوادگی، سن، قد، وزن، شماره تماس و ایمیل) کامل ثبت شده است یا خیر
  bool get isProfileComplete {
    return firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        phone.trim().length >= 8 &&
        email.trim().contains('@') &&
        age >= 10 &&
        heightCm >= 100 &&
        weightKg >= 30;
  }

  static String generateAccessCode() {
    final rng = Random.secure();
    final digits = List.generate(6, (_) => rng.nextInt(10)).join();
    return 'PC-$digits';
  }

  AthleteEntity copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? accessCode,
    int? streakDays,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? fitnessGoal,
    List<String>? injuryTags,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return AthleteEntity(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      accessCode: accessCode ?? this.accessCode,
      streakDays: streakDays ?? this.streakDays,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      injuryTags: injuryTags ?? this.injuryTags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'email': email,
        'access_code':
            accessCode.isNotEmpty ? accessCode : generateAccessCode(),
        'streak_days': streakDays,
        'gender': gender,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'fitness_goal': fitnessGoal,
        'injury_tags': jsonEncode(injuryTags),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted,
      };
}

class MeasurementLogEntity {
  final String id;
  final String athleteId;
  final DateTime recordedAt;
  final double weightKg;
  final double? bodyFatPercent;
  final double? shoulderCm;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? bicepsCm;
  final double? forearmCm;
  final double? thighCm;
  final double? calfCm;
  final DateTime updatedAt;
  final String syncStatus;

  const MeasurementLogEntity({
    required this.id,
    required this.athleteId,
    required this.recordedAt,
    required this.weightKg,
    this.bodyFatPercent,
    this.shoulderCm,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.bicepsCm,
    this.forearmCm,
    this.thighCm,
    this.calfCm,
    required this.updatedAt,
    this.syncStatus = 'pending_insert',
  });

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'athlete_id': athleteId,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'weight_kg': weightKg,
        'body_fat_percent': bodyFatPercent,
        'shoulder_cm': shoulderCm,
        'chest_cm': chestCm,
        'waist_cm': waistCm,
        'hips_cm': hipsCm,
        'biceps_cm': bicepsCm,
        'forearm_cm': forearmCm,
        'thigh_cm': thighCm,
        'calf_cm': calfCm,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

/// مدل پیام چت متنی خالص (Pure Text Chat) بین مربی و ورزشکار
class ChatMessageEntity {
  final String id;
  final String athleteId;
  final String senderRole; // 'coach' | 'athlete'
  final String messageText;
  final DateTime createdAt;
  final String syncStatus;

  const ChatMessageEntity({
    required this.id,
    required this.athleteId,
    required this.senderRole,
    required this.messageText,
    required this.createdAt,
    this.syncStatus = 'pending_insert',
  });

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'athlete_id': athleteId,
        'sender_role': senderRole,
        'message_text': messageText.length > 600
            ? messageText.substring(0, 600)
            : messageText,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

/// مدل ثبت لاگ جلسه تمرینی، رکوردهای وزنه (PR) و آب مصرفی شاگرد
class AthleteWorkoutLogEntity {
  final String id;
  final String athleteId;
  final String programId;
  final int dayNumber;
  final Map<String, double> exerciseMaxWeights; // exerciseId -> maxKgMoved
  final int waterGlasses;
  final int sessionRpe;
  final String athleteFeedback;
  final DateTime loggedAt;
  final String syncStatus;

  AthleteWorkoutLogEntity({
    required this.id,
    required this.athleteId,
    required this.programId,
    required this.dayNumber,
    Map<String, double>? exerciseMaxWeights,
    Map<String, dynamic>? exerciseWeightsKg,
    this.waterGlasses = 0,
    this.sessionRpe = 7,
    this.athleteFeedback = '',
    required this.loggedAt,
    this.syncStatus = 'pending_insert',
  }) : exerciseMaxWeights = exerciseMaxWeights ??
            (exerciseWeightsKg != null
                ? exerciseWeightsKg.map((k, v) => MapEntry(
                    k, (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0)))
                : const {});

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'athlete_id': athleteId,
        'program_id': programId,
        'day_number': dayNumber,
        'completed_sets_json': jsonEncode(exerciseMaxWeights),
        'water_glasses': waterGlasses,
        'session_rpe': sessionRpe,
        'athlete_feedback': athleteFeedback,
        'logged_at': loggedAt.toUtc().toIso8601String(),
      };
}

class WorkoutItemEntity {
  final String id;
  final String exerciseId;
  final String exerciseNameFa;
  final String exerciseNameEn;
  final String targetMuscle;
  final String imageStartUrl;
  final String imageEndUrl;
  final int orderIndex;
  final SetType setType;
  final String? supersetGroupId;
  final List<SingleSetConfig> sets;
  final String coachNote;

  const WorkoutItemEntity({
    required this.id,
    required this.exerciseId,
    required this.exerciseNameFa,
    required this.exerciseNameEn,
    required this.targetMuscle,
    required this.imageStartUrl,
    required this.imageEndUrl,
    required this.orderIndex,
    this.setType = SetType.normal,
    this.supersetGroupId,
    required this.sets,
    this.coachNote = '',
  });

  WorkoutItemEntity copyWith({
    int? orderIndex,
    SetType? setType,
    String? supersetGroupId,
    bool clearSuperset = false,
    List<SingleSetConfig>? sets,
    String? coachNote,
  }) {
    return WorkoutItemEntity(
      id: id,
      exerciseId: exerciseId,
      exerciseNameFa: exerciseNameFa,
      exerciseNameEn: exerciseNameEn,
      targetMuscle: targetMuscle,
      imageStartUrl: imageStartUrl,
      imageEndUrl: imageEndUrl,
      orderIndex: orderIndex ?? this.orderIndex,
      setType: setType ?? this.setType,
      supersetGroupId:
          clearSuperset ? null : (supersetGroupId ?? this.supersetGroupId),
      sets: sets ?? this.sets,
      coachNote: coachNote ?? this.coachNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'exerciseNameFa': exerciseNameFa,
        'exerciseNameEn': exerciseNameEn,
        'targetMuscle': targetMuscle,
        'imageStartUrl': imageStartUrl,
        'imageEndUrl': imageEndUrl,
        'orderIndex': orderIndex,
        'setType': setType.name,
        'supersetGroupId': supersetGroupId,
        'sets': sets.map((s) => s.toJson()).toList(),
        'coachNote': coachNote,
      };

  factory WorkoutItemEntity.fromJson(Map<String, dynamic> json) {
    return WorkoutItemEntity(
      id: json['id'] ?? const Uuid().v4(),
      exerciseId: json['exerciseId'] ?? '',
      exerciseNameFa: json['exerciseNameFa'] ?? '',
      exerciseNameEn: json['exerciseNameEn'] ?? '',
      targetMuscle: json['targetMuscle'] ?? '',
      imageStartUrl: json['imageStartUrl'] ?? '',
      imageEndUrl: json['imageEndUrl'] ?? '',
      orderIndex: json['orderIndex'] ?? 0,
      setType: SetType.values.firstWhere(
        (e) => e.name == (json['setType'] ?? 'normal'),
        orElse: () => SetType.normal,
      ),
      supersetGroupId: json['supersetGroupId'],
      sets: (json['sets'] as List<dynamic>? ?? [])
          .map((e) => SingleSetConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      coachNote: json['coachNote'] ?? '',
    );
  }
}

class WorkoutDayPlan {
  final int dayNumber;
  final String dayNameFa;
  final String dayNameEn;
  final bool isRestDay;
  final List<String> targetMuscles;
  final List<WorkoutItemEntity> exercises;

  const WorkoutDayPlan({
    required this.dayNumber,
    required this.dayNameFa,
    required this.dayNameEn,
    this.isRestDay = false,
    this.targetMuscles = const [],
    this.exercises = const [],
  });

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'dayNameFa': dayNameFa,
        'dayNameEn': dayNameEn,
        'isRestDay': isRestDay,
        'targetMuscles': targetMuscles,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDayPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutDayPlan(
      dayNumber: json['dayNumber'] ?? 1,
      dayNameFa: json['dayNameFa'] ?? '',
      dayNameEn: json['dayNameEn'] ?? '',
      isRestDay: json['isRestDay'] ?? false,
      targetMuscles: List<String>.from(json['targetMuscles'] ?? []),
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => WorkoutItemEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FullProgramEntity {
  final String id;
  final String athleteId;
  final String title;
  final DateTime startDate;
  final int durationWeeks;
  final List<WorkoutDayPlan> days;
  final List<DietMealSlot> dietMeals;
  final double waterLiters;
  final List<String> dietGuidelines;
  final List<SupplementPrescriptionItem> supplements;
  final double totalFee;
  final double paidAmount;
  final String paymentStatus;
  final bool isTemplate;
  final DateTime updatedAt;
  final String syncStatus;

  const FullProgramEntity({
    required this.id,
    required this.athleteId,
    required this.title,
    required this.startDate,
    this.durationWeeks = 4,
    required this.days,
    required this.dietMeals,
    this.waterLiters = 3.5,
    this.dietGuidelines = const [],
    required this.supplements,
    this.totalFee = 0,
    this.paidAmount = 0,
    this.paymentStatus = 'paid',
    this.isTemplate = false,
    required this.updatedAt,
    this.syncStatus = 'pending_insert',
  });

  DateTime get expirationDate =>
      startDate.add(Duration(days: durationWeeks * 7));

  int get remainingDays => expirationDate.difference(DateTime.now()).inDays;

  double get remainingDebt => (totalFee - paidAmount).clamp(0, double.infinity);

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'athlete_id': athleteId,
        'title': title,
        'start_date': startDate.toUtc().toIso8601String(),
        'duration_weeks': durationWeeks,
        'days_json': jsonEncode(days.map((e) => e.toJson()).toList()),
        'diet_meals_json': DietMealSlot.encodeList(dietMeals),
        'water_liters': waterLiters,
        'diet_guidelines_json': jsonEncode(dietGuidelines),
        'supplements_json': SupplementPrescriptionItem.encodeList(supplements),
        'total_fee': totalFee,
        'paid_amount': paidAmount,
        'payment_status': paymentStatus,
        'is_template': isTemplate,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

class LocalAppDatabase {
  late final Database _db;

  LocalAppDatabase._(this._db);

  static Future<LocalAppDatabase> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'pro_coach_offline_v1.sqlite');
    final db = sqlite3.open(dbPath);
    final instance = LocalAppDatabase._(db);
    instance._createTablesAndSeed();
    return instance;
  }

  static LocalAppDatabase initInMemoryForTesting() {
    final db = sqlite3.openInMemory();
    final instance = LocalAppDatabase._(db);
    instance._createTablesAndSeed();
    return instance;
  }

  void _createTablesAndSeed() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS athletes (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT DEFAULT '',
        access_code TEXT DEFAULT '',
        streak_days INTEGER DEFAULT 1,
        gender TEXT NOT NULL,
        age INTEGER NOT NULL,
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL,
        fitness_goal TEXT NOT NULL,
        injury_tags TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending_insert'
      );

      CREATE TABLE IF NOT EXISTS measurement_logs (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        body_fat_percent REAL,
        shoulder_cm REAL,
        chest_cm REAL,
        waist_cm REAL,
        hips_cm REAL,
        biceps_cm REAL,
        forearm_cm REAL,
        thigh_cm REAL,
        calf_cm REAL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending_insert'
      );

      CREATE TABLE IF NOT EXISTS programs (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        title TEXT NOT NULL,
        start_date TEXT NOT NULL,
        duration_weeks INTEGER NOT NULL,
        days_json TEXT NOT NULL,
        diet_meals_json TEXT NOT NULL,
        water_liters REAL NOT NULL,
        diet_guidelines_json TEXT NOT NULL,
        supplements_json TEXT NOT NULL,
        total_fee REAL NOT NULL,
        paid_amount REAL NOT NULL,
        payment_status TEXT NOT NULL,
        is_template INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending_insert'
      );

      -- جدول ذخیره خودکار پیشنویس برنامه تمرینی/غذایی (Auto-Draft - رفع عیب ۱ گزارش ممیزی)
      CREATE TABLE IF NOT EXISTS program_drafts (
        athlete_id TEXT PRIMARY KEY,
        draft_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        sender_role TEXT NOT NULL,
        message_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending_insert'
      );

      CREATE TABLE IF NOT EXISTS athlete_workout_logs (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        day_number INTEGER NOT NULL,
        completed_sets_json TEXT NOT NULL,
        water_glasses INTEGER NOT NULL DEFAULT 0,
        session_rpe INTEGER NOT NULL DEFAULT 7,
        athlete_feedback TEXT NOT NULL DEFAULT '',
        logged_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending_insert'
      );

      CREATE TABLE IF NOT EXISTS exercises_catalog (
        id TEXT PRIMARY KEY,
        name_fa TEXT NOT NULL,
        name_en TEXT NOT NULL,
        target_muscle TEXT NOT NULL,
        equipment TEXT NOT NULL,
        image_start_url TEXT NOT NULL,
        image_end_url TEXT NOT NULL,
        contraindicated_injuries TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS custom_foods_catalog (
        id TEXT PRIMARY KEY,
        name_fa TEXT NOT NULL,
        name_en TEXT NOT NULL,
        unit_fa TEXT NOT NULL,
        unit_en TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS custom_supplements_catalog (
        id TEXT PRIMARY KEY,
        name_fa TEXT NOT NULL,
        name_en TEXT NOT NULL,
        dosage_fa TEXT NOT NULL,
        dosage_en TEXT NOT NULL,
        timing_fa TEXT NOT NULL,
        timing_en TEXT NOT NULL
      );
    ''');

    // مهاجرت ایمن ستونهای جدید در صورت وجود دیتابیس از نسخه قبلی
    try {
      _db.execute("ALTER TABLE athletes ADD COLUMN email TEXT DEFAULT '';");
    } catch (_) {}
    try {
      _db.execute(
          "ALTER TABLE athletes ADD COLUMN access_code TEXT DEFAULT '';");
    } catch (_) {}
    try {
      _db.execute(
          'ALTER TABLE athletes ADD COLUMN streak_days INTEGER DEFAULT 1;');
    } catch (_) {}

    // Seed کردن حرکات پایه (INSERT OR IGNORE تا همیشه همه حرکات جدید اضافه شوند)
    final exStmt = _db.prepare('''
      INSERT OR IGNORE INTO exercises_catalog (
        id, name_fa, name_en, target_muscle, equipment,
        image_start_url, image_end_url, contraindicated_injuries
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    for (final ex in SeedCatalogData.initialExercises) {
      exStmt.execute([
        ex.id,
        ex.nameFa,
        ex.nameEn,
        ex.targetMuscle,
        ex.equipment,
        ex.imageStartUrl,
        ex.imageEndUrl,
        jsonEncode(ex.contraindicatedInjuries),
      ]);
    }
    exStmt.dispose();

    // Seed کردن بانک جامع ۴۰ غذای پایه
    final foodStmt = _db.prepare('''
      INSERT OR IGNORE INTO custom_foods_catalog (id, name_fa, name_en, unit_fa, unit_en)
      VALUES (?, ?, ?, ?, ?)
    ''');
    int i = 1;
    for (final f in SeedCatalogData.quickFoodCatalog) {
      foodStmt.execute([
        'food_$i',
        f['nameFa']!,
        f['nameEn']!,
        f['unitFa']!,
        f['unitEn']!
      ]);
      i++;
    }
    foodStmt.dispose();

    // Seed کردن بانک جامع ۳۰ مکمل، ویتامین و مینرال
    final suppStmt = _db.prepare('''
      INSERT OR IGNORE INTO custom_supplements_catalog (
        id, name_fa, name_en, dosage_fa, dosage_en, timing_fa, timing_en
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    for (final s in SeedCatalogData.supplementCatalog) {
      suppStmt.execute([
        s['id']!,
        s['nameFa']!,
        s['nameEn']!,
        s['defaultDosageFa']!,
        s['defaultDosageEn']!,
        s['defaultTimingFa']!,
        s['defaultTimingEn']!,
      ]);
    }
    suppStmt.dispose();
  }

  /// دانلود و ایمپورت خودکار کل ۸۷۳ حرکت جهانی از GitHub در دیتابیس محلی SQLite
  Future<int> syncGlobal873ExercisesIntoCatalog() async {
    final currentCount =
        _db.select('SELECT COUNT(*) as cnt FROM exercises_catalog').first['cnt']
            as int;
    // اگر قبلاً بالای ۵۰۰ حرکت ایمپورت شده، دوباره دانلود نکن
    if (currentCount > 500) return currentCount;

    final globalMoves = await SeedCatalogData.fetchAll873GlobalExercises();
    if (globalMoves.isEmpty) return currentCount;

    final stmt = _db.prepare('''
      INSERT OR IGNORE INTO exercises_catalog (
        id, name_fa, name_en, target_muscle, equipment,
        image_start_url, image_end_url, contraindicated_injuries
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final ex in globalMoves) {
        stmt.execute([
          ex.id,
          ex.nameFa,
          ex.nameEn,
          ex.targetMuscle,
          ex.equipment,
          ex.imageStartUrl,
          ex.imageEndUrl,
          jsonEncode(ex.contraindicatedInjuries),
        ]);
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
    } finally {
      stmt.dispose();
    }

    return _db
        .select('SELECT COUNT(*) as cnt FROM exercises_catalog')
        .first['cnt'] as int;
  }

  // ===========================================================================
  // ۱. عملیات ورزشکاران و ورود با کد دعوت (Athletes & Access Code DAO)
  // ===========================================================================
  void upsertAthlete(AthleteEntity athlete) {
    final code = athlete.accessCode.trim().isNotEmpty
        ? athlete.accessCode.trim().toUpperCase()
        : AthleteEntity.generateAccessCode();

    _db.execute('''
      INSERT OR REPLACE INTO athletes (
        id, first_name, last_name, phone, email, access_code, streak_days,
        gender, age, height_cm, weight_kg, fitness_goal, injury_tags,
        created_at, updated_at, is_deleted, sync_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      athlete.id,
      athlete.firstName,
      athlete.lastName,
      athlete.phone,
      athlete.email,
      code,
      athlete.streakDays,
      athlete.gender,
      athlete.age,
      athlete.heightCm,
      athlete.weightKg,
      athlete.fitnessGoal,
      jsonEncode(athlete.injuryTags),
      athlete.createdAt.toUtc().toIso8601String(),
      athlete.updatedAt.toUtc().toIso8601String(),
      athlete.isDeleted ? 1 : 0,
      athlete.syncStatus,
    ]);
  }

  List<AthleteEntity> getAllActiveAthletes() {
    final rows = _db.select(
        'SELECT * FROM athletes WHERE is_deleted = 0 ORDER BY updated_at DESC');
    return rows.map(_mapRowToAthlete).toList();
  }

  AthleteEntity? getAthleteById(String id) {
    final rows =
        _db.select('SELECT * FROM athletes WHERE id = ? LIMIT 1', [id]);
    if (rows.isEmpty) return null;
    return _mapRowToAthlete(rows.first);
  }

  AthleteEntity? getAthleteByAccessCode(String code) {
    final normalized = code.trim().toUpperCase();
    final rows = _db.select(
      'SELECT * FROM athletes WHERE UPPER(access_code) = ? AND is_deleted = 0 LIMIT 1',
      [normalized],
    );
    if (rows.isEmpty) return null;
    return _mapRowToAthlete(rows.first);
  }

  void softDeleteAthlete(String id) {
    _db.execute('''
      UPDATE athletes
      SET is_deleted = 1, updated_at = ?, sync_status = 'pending_delete'
      WHERE id = ?
    ''', [DateTime.now().toUtc().toIso8601String(), id]);
  }

  AthleteEntity _mapRowToAthlete(Row row) {
    String code = (row['access_code'] as String?) ?? '';
    if (code.isEmpty) {
      code = AthleteEntity.generateAccessCode();
      _db.execute('UPDATE athletes SET access_code = ? WHERE id = ?',
          [code, row['id']]);
    }
    return AthleteEntity(
      id: row['id'] as String,
      firstName: row['first_name'] as String,
      lastName: row['last_name'] as String,
      phone: row['phone'] as String,
      email: (row['email'] as String?) ?? '',
      accessCode: code,
      streakDays: (row['streak_days'] as int?) ?? 1,
      gender: row['gender'] as String,
      age: row['age'] as int,
      heightCm: (row['height_cm'] as num).toDouble(),
      weightKg: (row['weight_kg'] as num).toDouble(),
      fitnessGoal: row['fitness_goal'] as String,
      injuryTags: List<String>.from(jsonDecode(row['injury_tags'] as String)),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      isDeleted: (row['is_deleted'] as int) == 1,
      syncStatus: row['sync_status'] as String,
    );
  }

  // ===========================================================================
  // ۲. عملیات چت متنی خالص (Pure Text Chat DAO) و گزارش تمرین شاگرد
  // ===========================================================================
  void insertChatMessage(ChatMessageEntity msg) {
    _db.execute('''
      INSERT OR REPLACE INTO chat_messages (
        id, athlete_id, sender_role, message_text, created_at, sync_status
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      msg.id,
      msg.athleteId,
      msg.senderRole,
      msg.messageText,
      msg.createdAt.toUtc().toIso8601String(),
      msg.syncStatus,
    ]);
  }

  List<ChatMessageEntity> getChatMessagesForAthlete(String athleteId) {
    final rows = _db.select(
      'SELECT * FROM chat_messages WHERE athlete_id = ? ORDER BY created_at ASC',
      [athleteId],
    );
    return rows.map((r) {
      return ChatMessageEntity(
        id: r['id'] as String,
        athleteId: r['athlete_id'] as String,
        senderRole: r['sender_role'] as String,
        messageText: r['message_text'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        syncStatus: r['sync_status'] as String,
      );
    }).toList();
  }

  void insertWorkoutSessionLog(AthleteWorkoutLogEntity log) {
    _db.execute('''
      INSERT OR REPLACE INTO athlete_workout_logs (
        id, athlete_id, program_id, day_number, completed_sets_json,
        water_glasses, session_rpe, athlete_feedback, logged_at, sync_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      log.id,
      log.athleteId,
      log.programId,
      log.dayNumber,
      jsonEncode(log.exerciseMaxWeights),
      log.waterGlasses,
      log.sessionRpe,
      log.athleteFeedback,
      log.loggedAt.toUtc().toIso8601String(),
      log.syncStatus,
    ]);

    // افزایش خودکار روزهای استمرار (Streak) ورزشکار پس از ثبت جلسه تمرینی
    _db.execute('''
      UPDATE athletes
      SET streak_days = streak_days + 1, updated_at = ?, sync_status = 'pending_update'
      WHERE id = ?
    ''', [DateTime.now().toUtc().toIso8601String(), log.athleteId]);
  }

  void upsertWorkoutLog(AthleteWorkoutLogEntity log) =>
      insertWorkoutSessionLog(log);

  List<AthleteWorkoutLogEntity> getWorkoutLogsForAthlete(String athleteId) {
    final rows = _db.select(
      'SELECT * FROM athlete_workout_logs WHERE athlete_id = ? ORDER BY logged_at DESC',
      [athleteId],
    );
    return rows.map((r) {
      final rawMap =
          jsonDecode(r['completed_sets_json'] as String) as Map<String, dynamic>;
      final weights =
          rawMap.map((k, v) => MapEntry(k, (v as num).toDouble()));
      return AthleteWorkoutLogEntity(
        id: r['id'] as String,
        athleteId: r['athlete_id'] as String,
        programId: r['program_id'] as String,
        dayNumber: r['day_number'] as int,
        exerciseMaxWeights: weights,
        waterGlasses: r['water_glasses'] as int,
        sessionRpe: r['session_rpe'] as int,
        athleteFeedback: (r['athlete_feedback'] as String?) ?? '',
        loggedAt: DateTime.parse(r['logged_at'] as String).toLocal(),
        syncStatus: r['sync_status'] as String,
      );
    }).toList();
  }

  // ===========================================================================
  // ۳. عملیات سایزگیری (Measurements DAO)
  // ===========================================================================
  void insertMeasurementLog(MeasurementLogEntity log) {
    _db.execute('''
      INSERT OR REPLACE INTO measurement_logs (
        id, athlete_id, recorded_at, weight_kg, body_fat_percent,
        shoulder_cm, chest_cm, waist_cm, hips_cm, biceps_cm,
        forearm_cm, thigh_cm, calf_cm, updated_at, sync_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      log.id,
      log.athleteId,
      log.recordedAt.toUtc().toIso8601String(),
      log.weightKg,
      log.bodyFatPercent,
      log.shoulderCm,
      log.chestCm,
      log.waistCm,
      log.hipsCm,
      log.bicepsCm,
      log.forearmCm,
      log.thighCm,
      log.calfCm,
      log.updatedAt.toUtc().toIso8601String(),
      log.syncStatus,
    ]);

    _db.execute('''
      UPDATE athletes SET weight_kg = ?, updated_at = ?, sync_status = 'pending_update'
      WHERE id = ?
    ''', [
      log.weightKg,
      DateTime.now().toUtc().toIso8601String(),
      log.athleteId
    ]);
  }

  List<MeasurementLogEntity> getMeasurementsForAthlete(String athleteId) {
    final rows = _db.select(
      'SELECT * FROM measurement_logs WHERE athlete_id = ? ORDER BY recorded_at ASC',
      [athleteId],
    );
    return rows.map((row) {
      return MeasurementLogEntity(
        id: row['id'] as String,
        athleteId: row['athlete_id'] as String,
        recordedAt: DateTime.parse(row['recorded_at'] as String).toLocal(),
        weightKg: (row['weight_kg'] as num).toDouble(),
        bodyFatPercent: (row['body_fat_percent'] as num?)?.toDouble(),
        shoulderCm: (row['shoulder_cm'] as num?)?.toDouble(),
        chestCm: (row['chest_cm'] as num?)?.toDouble(),
        waistCm: (row['waist_cm'] as num?)?.toDouble(),
        hipsCm: (row['hips_cm'] as num?)?.toDouble(),
        bicepsCm: (row['biceps_cm'] as num?)?.toDouble(),
        forearmCm: (row['forearm_cm'] as num?)?.toDouble(),
        thighCm: (row['thigh_cm'] as num?)?.toDouble(),
        calfCm: (row['calf_cm'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        syncStatus: row['sync_status'] as String,
      );
    }).toList();
  }

  // ===========================================================================
  // ۴. عملیات برنامهها، قالبها و تسویه بدهی مالی (Programs & Billing DAO)
  // ===========================================================================
  void upsertProgram(FullProgramEntity program) {
    _db.execute('''
      INSERT OR REPLACE INTO programs (
        id, athlete_id, title, start_date, duration_weeks,
        days_json, diet_meals_json, water_liters, diet_guidelines_json,
        supplements_json, total_fee, paid_amount, payment_status,
        is_template, updated_at, sync_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      program.id,
      program.athleteId,
      program.title,
      program.startDate.toUtc().toIso8601String(),
      program.durationWeeks,
      jsonEncode(program.days.map((d) => d.toJson()).toList()),
      DietMealSlot.encodeList(program.dietMeals),
      program.waterLiters,
      jsonEncode(program.dietGuidelines),
      SupplementPrescriptionItem.encodeList(program.supplements),
      program.totalFee,
      program.paidAmount,
      program.paymentStatus,
      program.isTemplate ? 1 : 0,
      program.updatedAt.toUtc().toIso8601String(),
      program.syncStatus,
    ]);
  }

  void settleProgramDebt(String programId) {
    _db.execute('''
      UPDATE programs
      SET paid_amount = total_fee, payment_status = 'paid', updated_at = ?, sync_status = 'pending_update'
      WHERE id = ?
    ''', [DateTime.now().toUtc().toIso8601String(), programId]);
  }

  void deleteProgramOrTemplate(String programId) {
    _db.execute('DELETE FROM programs WHERE id = ?', [programId]);
  }

  List<FullProgramEntity> getProgramsForAthlete(String athleteId) {
    final rows = _db.select(
      'SELECT * FROM programs WHERE athlete_id = ? AND is_template = 0 ORDER BY start_date DESC',
      [athleteId],
    );
    return rows.map(_mapRowToProgram).toList();
  }

  List<FullProgramEntity> getAllPrograms({bool includeTemplates = false}) {
    final query = includeTemplates
        ? 'SELECT * FROM programs ORDER BY updated_at DESC'
        : 'SELECT * FROM programs WHERE is_template = 0 ORDER BY updated_at DESC';
    return _db.select(query).map(_mapRowToProgram).toList();
  }

  List<FullProgramEntity> getSavedTemplates() {
    final rows = _db.select(
        'SELECT * FROM programs WHERE is_template = 1 ORDER BY updated_at DESC');
    return rows.map(_mapRowToProgram).toList();
  }

  FullProgramEntity _mapRowToProgram(Row row) {
    final daysList = (jsonDecode(row['days_json'] as String) as List<dynamic>)
        .map((e) => WorkoutDayPlan.fromJson(e as Map<String, dynamic>))
        .toList();

    return FullProgramEntity(
      id: row['id'] as String,
      athleteId: row['athlete_id'] as String,
      title: row['title'] as String,
      startDate: DateTime.parse(row['start_date'] as String).toLocal(),
      durationWeeks: row['duration_weeks'] as int,
      days: daysList,
      dietMeals: DietMealSlot.decodeList(row['diet_meals_json'] as String),
      waterLiters: (row['water_liters'] as num).toDouble(),
      dietGuidelines:
          List<String>.from(jsonDecode(row['diet_guidelines_json'] as String)),
      supplements: SupplementPrescriptionItem.decodeList(
          row['supplements_json'] as String),
      totalFee: (row['total_fee'] as num).toDouble(),
      paidAmount: (row['paid_amount'] as num).toDouble(),
      paymentStatus: row['payment_status'] as String,
      isTemplate: (row['is_template'] as int) == 1,
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      syncStatus: row['sync_status'] as String,
    );
  }

  // ===========================================================================
  // ۵. کاتالوگ حرکات، غذاها و مکملها
  // ===========================================================================
  List<ExerciseSeedItem> getExercisesCatalog({
    String? muscleFilter,
    String? searchQuery,
  }) {
    final rows = muscleFilter == null || muscleFilter.isEmpty
        ? _db.select('SELECT * FROM exercises_catalog ORDER BY name_fa ASC')
        : _db.select(
            'SELECT * FROM exercises_catalog WHERE target_muscle = ? ORDER BY name_fa ASC',
            [muscleFilter],
          );

    final list = rows.map((r) {
      return ExerciseSeedItem(
        id: r['id'] as String,
        nameFa: r['name_fa'] as String,
        nameEn: r['name_en'] as String,
        targetMuscle: r['target_muscle'] as String,
        equipment: r['equipment'] as String,
        imageStartUrl: r['image_start_url'] as String,
        imageEndUrl: r['image_end_url'] as String,
        contraindicatedInjuries: List<String>.from(
            jsonDecode(r['contraindicated_injuries'] as String)),
      );
    }).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      return list.where((ex) {
        return ex.id.toLowerCase().contains(q) ||
            ex.nameFa.toLowerCase().contains(q) ||
            ex.nameEn.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void addCustomExercise(ExerciseSeedItem item) {
    _db.execute('''
      INSERT OR REPLACE INTO exercises_catalog (
        id, name_fa, name_en, target_muscle, equipment,
        image_start_url, image_end_url, contraindicated_injuries
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      item.id,
      item.nameFa,
      item.nameEn,
      item.targetMuscle,
      item.equipment,
      item.imageStartUrl,
      item.imageEndUrl,
      jsonEncode(item.contraindicatedInjuries),
    ]);
  }

  List<Map<String, String>> getFoodsCatalog() {
    final rows =
        _db.select('SELECT * FROM custom_foods_catalog ORDER BY rowid DESC');
    return rows.map((r) {
      return {
        'id': r['id'] as String,
        'nameFa': r['name_fa'] as String,
        'nameEn': r['name_en'] as String,
        'unitFa': r['unit_fa'] as String,
        'unitEn': r['unit_en'] as String,
      };
    }).toList();
  }

  void addCustomFood({
    required String nameFa,
    required String nameEn,
    required String unitFa,
    required String unitEn,
  }) {
    _db.execute('''
      INSERT INTO custom_foods_catalog (id, name_fa, name_en, unit_fa, unit_en)
      VALUES (?, ?, ?, ?, ?)
    ''', [const Uuid().v4(), nameFa, nameEn, unitFa, unitEn]);
  }

  List<Map<String, String>> getSupplementsCatalog() {
    final rows = _db.select(
        'SELECT * FROM custom_supplements_catalog ORDER BY rowid DESC');
    return rows.map((r) {
      return {
        'id': r['id'] as String,
        'nameFa': r['name_fa'] as String,
        'nameEn': r['name_en'] as String,
        'defaultDosageFa': r['dosage_fa'] as String,
        'defaultDosageEn': r['dosage_en'] as String,
        'defaultTimingFa': r['timing_fa'] as String,
        'defaultTimingEn': r['timing_en'] as String,
      };
    }).toList();
  }

  void addCustomSupplement({
    required String nameFa,
    required String nameEn,
    required String dosageFa,
    required String dosageEn,
    required String timingFa,
    required String timingEn,
  }) {
    _db.execute('''
      INSERT INTO custom_supplements_catalog (
        id, name_fa, name_en, dosage_fa, dosage_en, timing_fa, timing_en
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      const Uuid().v4(),
      nameFa,
      nameEn,
      dosageFa,
      dosageEn,
      timingFa,
      timingEn
    ]);
  }

  // ===========================================================================
  // ۶. صف همگامسازی ابری (Outbox Queue) + بکاپ و بازیابی کامل دوطرفه JSON
  // ===========================================================================
  List<AthleteEntity> getPendingSyncAthletes() {
    final rows =
        _db.select("SELECT * FROM athletes WHERE sync_status != 'synced'");
    return rows.map(_mapRowToAthlete).toList();
  }

  List<MeasurementLogEntity> getPendingSyncMeasurements() {
    final rows = _db
        .select("SELECT * FROM measurement_logs WHERE sync_status != 'synced'");
    return rows.map((row) {
      return MeasurementLogEntity(
        id: row['id'] as String,
        athleteId: row['athlete_id'] as String,
        recordedAt: DateTime.parse(row['recorded_at'] as String).toLocal(),
        weightKg: (row['weight_kg'] as num).toDouble(),
        bodyFatPercent: (row['body_fat_percent'] as num?)?.toDouble(),
        shoulderCm: (row['shoulder_cm'] as num?)?.toDouble(),
        chestCm: (row['chest_cm'] as num?)?.toDouble(),
        waistCm: (row['waist_cm'] as num?)?.toDouble(),
        hipsCm: (row['hips_cm'] as num?)?.toDouble(),
        bicepsCm: (row['biceps_cm'] as num?)?.toDouble(),
        forearmCm: (row['forearm_cm'] as num?)?.toDouble(),
        thighCm: (row['thigh_cm'] as num?)?.toDouble(),
        calfCm: (row['calf_cm'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        syncStatus: row['sync_status'] as String,
      );
    }).toList();
  }

  List<FullProgramEntity> getPendingSyncPrograms() {
    final rows =
        _db.select("SELECT * FROM programs WHERE sync_status != 'synced'");
    return rows.map(_mapRowToProgram).toList();
  }

  List<ChatMessageEntity> getPendingSyncChatMessages() {
    final rows =
        _db.select("SELECT * FROM chat_messages WHERE sync_status != 'synced'");
    return rows.map((r) {
      return ChatMessageEntity(
        id: r['id'] as String,
        athleteId: r['athlete_id'] as String,
        senderRole: r['sender_role'] as String,
        messageText: r['message_text'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        syncStatus: r['sync_status'] as String,
      );
    }).toList();
  }

  void markRecordSynced(String table, String id) {
    const allowedTables = {
      'athletes',
      'measurement_logs',
      'programs',
      'chat_messages',
      'athlete_workout_logs',
    };
    if (!allowedTables.contains(table)) {
      throw ArgumentError('Invalid table name for sync: $table');
    }
    _db.execute("UPDATE $table SET sync_status = 'synced' WHERE id = ?", [id]);
  }

  List<ExerciseSeedItem> getCustomExercisesOnly() {
    final rows = _db.select(
        "SELECT * FROM exercises_catalog WHERE id LIKE 'custom_%' OR equipment = 'custom'");
    return rows.map((r) {
      return ExerciseSeedItem(
        id: r['id'] as String,
        nameFa: r['name_fa'] as String,
        nameEn: r['name_en'] as String,
        targetMuscle: r['target_muscle'] as String,
        equipment: r['equipment'] as String,
        imageStartUrl: r['image_start_url'] as String,
        imageEndUrl: r['image_end_url'] as String,
        contraindicatedInjuries: List<String>.from(
            jsonDecode(r['contraindicated_injuries'] as String)),
      );
    }).toList();
  }

  /// خروجی کامل بکاپ به فرمت JSON
  String exportFullDatabaseToJson() {
    final payload = {
      'version': '2.0',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'athletes':
          getAllActiveAthletes().map((a) => a.toSupabaseJson()).toList(),
      'programs': getAllPrograms(includeTemplates: true)
          .map((p) => p.toSupabaseJson())
          .toList(),
      'custom_foods': getFoodsCatalog(),
      'custom_supplements': getSupplementsCatalog(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// بازیابی کامل اطلاعات از رشته JSON بکاپ (Restore Engine)
  int restoreFullDatabaseFromJson(String jsonStr) {
    final Map<String, dynamic> decoded = jsonDecode(jsonStr);
    int restoredCount = 0;

    final athletesList = (decoded['athletes'] as List<dynamic>? ?? []);
    for (final raw in athletesList) {
      final row = raw as Map<String, dynamic>;
      final rawTags = row['injury_tags'];
      final List<String> parsedTags = rawTags is String
          ? List<String>.from(jsonDecode(rawTags))
          : List<String>.from(rawTags ?? []);

      upsertAthlete(AthleteEntity(
        id: row['id'] as String,
        firstName: row['first_name'] as String? ?? '',
        lastName: row['last_name'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        email: row['email'] as String? ?? '',
        accessCode: row['access_code'] as String? ?? '',
        streakDays: (row['streak_days'] as num?)?.toInt() ?? 1,
        gender: row['gender'] as String? ?? 'male',
        age: (row['age'] as num?)?.toInt() ?? 25,
        heightCm: (row['height_cm'] as num?)?.toDouble() ?? 175,
        weightKg: (row['weight_kg'] as num?)?.toDouble() ?? 75,
        fitnessGoal: row['fitness_goal'] as String? ?? 'lean_bulk',
        injuryTags: parsedTags,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        syncStatus: 'pending_insert',
      ));
      restoredCount++;
    }

    final programsList = (decoded['programs'] as List<dynamic>? ?? []);
    for (final raw in programsList) {
      final row = raw as Map<String, dynamic>;
      final rawDays = row['days_json'];
      final decodedDays =
          (rawDays is String ? jsonDecode(rawDays) : rawDays) as List<dynamic>;
      final rawMeals = row['diet_meals_json'];
      final mealsStr = rawMeals is String ? rawMeals : jsonEncode(rawMeals);
      final rawSupps = row['supplements_json'];
      final suppsStr = rawSupps is String ? rawSupps : jsonEncode(rawSupps);
      final rawGuides = row['diet_guidelines_json'];
      final List<String> guides = rawGuides is String
          ? List<String>.from(jsonDecode(rawGuides))
          : List<String>.from(rawGuides ?? []);

      upsertProgram(FullProgramEntity(
        id: row['id'] as String,
        athleteId: row['athlete_id'] as String,
        title: row['title'] as String? ?? '',
        startDate: DateTime.parse(row['start_date'] as String).toLocal(),
        durationWeeks: (row['duration_weeks'] as num?)?.toInt() ?? 4,
        days: decodedDays
            .map((e) => WorkoutDayPlan.fromJson(e as Map<String, dynamic>))
            .toList(),
        dietMeals: DietMealSlot.decodeList(mealsStr),
        waterLiters: (row['water_liters'] as num?)?.toDouble() ?? 3.5,
        dietGuidelines: guides,
        supplements: SupplementPrescriptionItem.decodeList(suppsStr),
        totalFee: (row['total_fee'] as num?)?.toDouble() ?? 0,
        paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
        paymentStatus: row['payment_status'] as String? ?? 'paid',
        isTemplate: (row['is_template'] as bool?) ?? false,
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        syncStatus: 'pending_insert',
      ));
    }

    return restoredCount;
  }


  // ===========================================================================
  // ۷. عملیات پیش‌نویس خودکار برنامه (Auto-Draft DAO)
  // ===========================================================================
  void saveProgramDraft(String athleteId, dynamic draft) {
    final String draftJson;
    if (draft is String) {
      draftJson = draft;
    } else if (draft is FullProgramEntity) {
      draftJson = jsonEncode(draft.toSupabaseJson());
    } else {
      draftJson = jsonEncode(draft);
    }

    _db.execute('''
      INSERT INTO program_drafts (athlete_id, draft_json, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(athlete_id) DO UPDATE SET
        draft_json = excluded.draft_json,
        updated_at = excluded.updated_at
    ''', [athleteId, draftJson, DateTime.now().toUtc().toIso8601String()]);
  }

  String? loadProgramDraft(String athleteId) {
    final rows = _db.select(
      'SELECT draft_json FROM program_drafts WHERE athlete_id = ? LIMIT 1',
      [athleteId],
    );
    if (rows.isEmpty) return null;
    return rows.first['draft_json'] as String?;
  }

  FullProgramEntity? getProgramDraft(String athleteId) {
    final raw = loadProgramDraft(athleteId);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawDays = decoded['days_json'] ?? decoded['days'];
      final List<dynamic> decodedDays;
      if (rawDays is String) {
        decodedDays = jsonDecode(rawDays) as List<dynamic>;
      } else if (rawDays is List) {
        decodedDays = rawDays;
      } else {
        decodedDays = [];
      }

      final rawMeals = decoded['diet_meals_json'] ?? decoded['diet_meals'];
      final mealsStr =
          rawMeals is String ? rawMeals : jsonEncode(rawMeals ?? []);

      final rawSupps = decoded['supplements_json'] ?? decoded['supplements'];
      final suppsStr =
          rawSupps is String ? rawSupps : jsonEncode(rawSupps ?? []);

      final rawGuides =
          decoded['diet_guidelines_json'] ?? decoded['diet_guidelines'];
      final List<String> guides = rawGuides is String
          ? List<String>.from(jsonDecode(rawGuides))
          : List<String>.from(rawGuides ?? []);

      return FullProgramEntity(
        id: decoded['id'] as String? ?? 'DRAFT_$athleteId',
        athleteId: athleteId,
        title: decoded['title'] as String? ?? '',
        startDate: decoded['start_date'] != null
            ? DateTime.parse(decoded['start_date'] as String).toLocal()
            : DateTime.now(),
        durationWeeks: (decoded['duration_weeks'] as num?)?.toInt() ?? 4,
        days: decodedDays
            .map((e) => WorkoutDayPlan.fromJson(e as Map<String, dynamic>))
            .toList(),
        dietMeals: DietMealSlot.decodeList(mealsStr),
        waterLiters: (decoded['water_liters'] as num?)?.toDouble() ?? 3.5,
        dietGuidelines: guides,
        supplements: SupplementPrescriptionItem.decodeList(suppsStr),
        totalFee: (decoded['total_fee'] as num?)?.toDouble() ?? 0,
        paidAmount: (decoded['paid_amount'] as num?)?.toDouble() ?? 0,
        paymentStatus: decoded['payment_status'] as String? ?? 'paid',
        isTemplate: (decoded['is_template'] as bool?) ?? false,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  void deleteProgramDraft(String athleteId) {
    _db.execute('DELETE FROM program_drafts WHERE athlete_id = ?', [athleteId]);
  }

  void clearProgramDraft(String athleteId) => deleteProgramDraft(athleteId);

  List<AthleteWorkoutLogEntity> getPendingSyncWorkoutLogs() {
    final rows = _db.select(
        "SELECT * FROM athlete_workout_logs WHERE sync_status != 'synced'");
    return rows.map((r) {
      final rawMap =
          jsonDecode(r['completed_sets_json'] as String) as Map<String, dynamic>;
      final weights =
          rawMap.map((k, v) => MapEntry(k, (v as num).toDouble()));
      return AthleteWorkoutLogEntity(
        id: r['id'] as String,
        athleteId: r['athlete_id'] as String,
        programId: r['program_id'] as String,
        dayNumber: r['day_number'] as int,
        exerciseMaxWeights: weights,
        waterGlasses: r['water_glasses'] as int,
        sessionRpe: r['session_rpe'] as int,
        athleteFeedback: (r['athlete_feedback'] as String?) ?? '',
        loggedAt: DateTime.parse(r['logged_at'] as String).toLocal(),
        syncStatus: r['sync_status'] as String,
      );
    }).toList();
  }

  int importGlobal800ExercisesBatch([List<dynamic>? rawList]) {
    if (rawList == null || rawList.isEmpty) {
      syncGlobal873ExercisesIntoCatalog();
      return 0;
    }
    final stmt = _db.prepare('''
      INSERT OR IGNORE INTO exercises_catalog (
        id, name_fa, name_en, target_muscle, equipment,
        image_start_url, image_end_url, contraindicated_injuries
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    int inserted = 0;
    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final raw in rawList) {
        if (raw is! Map<String, dynamic>) continue;
        final id = raw['id'] as String? ?? '';
        final nameEn = raw['name'] as String? ?? '';
        if (id.isEmpty || nameEn.isEmpty) continue;

        final primaryMuscles =
            List<String>.from(raw['primaryMuscles'] ?? const ['chest']);
        final rawMuscle =
            primaryMuscles.isNotEmpty ? primaryMuscles.first : 'chest';
        final targetMuscle = SeedCatalogData.mapGlobalMuscleGroup(rawMuscle);
        final equipment = (raw['equipment'] as String?) ?? 'bodyweight';

        final images = List<String>.from(raw['images'] ?? const []);
        const cdnBase =
            'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises';
        final imgStart = images.isNotEmpty
            ? '$cdnBase/${images.first}'
            : '$cdnBase/$id/0.jpg';
        final imgEnd = images.length > 1
            ? '$cdnBase/${images[1]}'
            : '$cdnBase/$id/1.jpg';

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

        stmt.execute([
          id,
          SeedCatalogData.translateExerciseNameToPersian(nameEn),
          nameEn,
          targetMuscle,
          equipment,
          imgStart,
          imgEnd,
          jsonEncode(injuries),
        ]);
        inserted++;
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
    } finally {
      stmt.dispose();
    }
    return inserted;
  }

  /// پاکسازی کامل داده‌های شخصی مربی از SQLite گوشی هنگام خروج از حساب (OWASP M9)
  void clearAllUserDataOnLogout() {
    _db.execute('DELETE FROM athletes;');
    _db.execute('DELETE FROM measurement_logs;');
    _db.execute('DELETE FROM programs;');
    _db.execute('DELETE FROM program_drafts;');
    _db.execute('DELETE FROM chat_messages;');
    _db.execute('DELETE FROM athlete_workout_logs;');
    _db.execute("DELETE FROM exercises_catalog WHERE id LIKE 'custom_%';");
    _db.execute("DELETE FROM custom_foods_catalog WHERE id NOT LIKE 'food_%';");
    _db.execute("DELETE FROM custom_supplements_catalog WHERE id NOT LIKE 'supp_%';");
  }
}
