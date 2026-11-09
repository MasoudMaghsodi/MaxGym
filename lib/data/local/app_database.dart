import 'dart:convert';
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

/// وضعیت همگامسازی رکوردهای محلی با Supabase
enum SyncStatus { synced, pendingInsert, pendingUpdate, pendingDelete }

/// مدل کامل ورزشکار (Step 1 Onboarding)
class AthleteEntity {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String gender; // 'male' | 'female'
  final int age;
  final double heightCm;
  final double weightKg;
  final String fitnessGoal; // 'weight_loss', 'lean_bulk', 'muscle_gain', 'maintenance'
  final List<String> injuryTags; // ['lower_back', 'knee', 'shoulder', ...]
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String syncStatus;

  const AthleteEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
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

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
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

/// مدل سایزگیری بدنی تاریخدار (Step 2 Anthropometrics)
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

/// مدل یک حرکت تمرینی داخل یک روز مشخص (شامل پشتیبانی از سوپرست و تمپو)
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
  final String? supersetGroupId; // اگر دو حرکت کد یکسان داشته باشند (مثلاً "SS-1") به هم قفل میشوند
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

/// مدل یک روز در برنامه هفتگی (Macro-to-Micro Split)
class WorkoutDayPlan {
  final int dayNumber; // 1 (شنبه/Sat) تا 7 (جمعه/Fri)
  final String dayNameFa;
  final String dayNameEn;
  final bool isRestDay;
  final List<String> targetMuscles; // ['chest', 'triceps']
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

/// مدل جامع برنامه اختصاصی ورزشکار (تمرین + تغذیه + مکمل + مالی + تاریخ انقضا)
class FullProgramEntity {
  final String id;
  final String athleteId;
  final String title;
  final DateTime startDate;
  final int durationWeeks; // مثلاً 4 یا 6 هفته
  final List<WorkoutDayPlan> days;
  final List<DietMealSlot> dietMeals;
  final double waterLiters;
  final List<String> dietGuidelines;
  final List<SupplementPrescriptionItem> supplements;

  // بخش مالی و شهریه این دوره
  final double totalFee;
  final double paidAmount;
  final String paymentStatus; // 'paid', 'partial', 'unpaid'

  final bool isTemplate; // آیا به عنوان قالب آماده هم ذخیره شده؟
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

/// کلاس مدیریت دیتابیس محلی SQLite با پشتیبانی از Outbox Sync Queue
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

  static LocalAppDatabase inMemory() {
    return initInMemoryForTesting();
  }

  /// سازنده مخصوص اجرای سریع Unit Test و Widget Test در حافظه RAM
  static LocalAppDatabase initInMemoryForTesting() {
    final db = sqlite3.openInMemory();
    final instance = LocalAppDatabase._(db);
    instance._createTablesAndSeed();
    return instance;
  }

  void close() {
    _db.dispose();
  }

  void _createTablesAndSeed() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS athletes (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        phone TEXT NOT NULL,
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
    ''');

    // Seed کردن کاتالوگ حرکات دوزبانه در صورت خالی بودن
    final countResult =
        _db.select('SELECT COUNT(*) as cnt FROM exercises_catalog');
    final count = countResult.first['cnt'] as int;
    if (count == 0) {
      final stmt = _db.prepare('''
        INSERT INTO exercises_catalog (
          id, name_fa, name_en, target_muscle, equipment,
          image_start_url, image_end_url, contraindicated_injuries
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      for (final ex in SeedCatalogData.initialExercises) {
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
      stmt.dispose();
    }
  }

  // ===========================================================================
  // ۱. عملیات مربوط به ورزشکاران (Athletes DAO)
  // ===========================================================================
  void upsertAthlete(AthleteEntity athlete) {
    _db.execute('''
      INSERT OR REPLACE INTO athletes (
        id, first_name, last_name, phone, gender, age,
        height_cm, weight_kg, fitness_goal, injury_tags,
        created_at, updated_at, is_deleted, sync_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      athlete.id,
      athlete.firstName,
      athlete.lastName,
      athlete.phone,
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

  void softDeleteAthlete(String id) {
    _db.execute('''
      UPDATE athletes
      SET is_deleted = 1, updated_at = ?, sync_status = 'pending_delete'
      WHERE id = ?
    ''', [DateTime.now().toUtc().toIso8601String(), id]);
  }

  AthleteEntity _mapRowToAthlete(Row row) {
    return AthleteEntity(
      id: row['id'] as String,
      firstName: row['first_name'] as String,
      lastName: row['last_name'] as String,
      phone: row['phone'] as String,
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
  // ۲. عملیات مربوط به سایزگیری و تاریخچه آنتروپومتریک (Measurements DAO)
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

    // بهروزرسانی وزن فعلی در پروفایل اصلی ورزشکار
    _db.execute('''
      UPDATE athletes SET weight_kg = ?, updated_at = ?, sync_status = 'pending_update'
      WHERE id = ?
    ''', [log.weightKg, DateTime.now().toUtc().toIso8601String(), log.athleteId]);
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
  // ۳. عملیات مربوط به برنامههای تمرینی، غذایی، مکمل، قالبها و مالی (Programs DAO)
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
  // ۴. کاتالوگ حرکات ورزشی (Exercises Catalog)
  // ===========================================================================
  List<ExerciseSeedItem> getExercisesCatalog({String? muscleFilter}) {
    final rows = muscleFilter == null || muscleFilter.isEmpty
        ? _db.select('SELECT * FROM exercises_catalog ORDER BY name_fa ASC')
        : _db.select(
            'SELECT * FROM exercises_catalog WHERE target_muscle = ? ORDER BY name_fa ASC',
            [muscleFilter],
          );

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

  // ===========================================================================
  // ۵. متدهای صف همگامسازی ابری (Outbox Queue for Supabase Sync)
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

  void markRecordSynced(String table, String id) {
    _db.execute(
        "UPDATE $table SET sync_status = 'synced' WHERE id = ?", [id]);
  }
}
