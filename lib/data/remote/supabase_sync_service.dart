import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../local/app_database.dart';
import '../local/database_models.dart';
import '../local/seed_catalog_data.dart';

final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SupabaseSyncService(db);
});

class SyncSummary {
  final int syncedAthletes;
  final int syncedMeasurements;
  final int syncedPrograms;
  final bool success;
  final String message;

  const SyncSummary({
    this.syncedAthletes = 0,
    this.syncedMeasurements = 0,
    this.syncedPrograms = 0,
    required this.success,
    required this.message,
  });
}

class SupabaseSyncService {
  final LocalAppDatabase _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  SupabaseSyncService(this._db);

  void startAutoSyncListener() {
    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet) {
        await syncAllPendingData();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  Future<SyncSummary> syncAllPendingData() async {
    if (_isSyncing) {
      return const SyncSummary(
          success: false, message: 'در حال همگامسازی...');
    }
    _isSyncing = true;

    try {
      if (!SupabaseConfig.isInitialized) {
        await SupabaseConfig.initializeSafely();
      }
      final client = SupabaseConfig.clientOrNull;
      final currentUser = client?.auth.currentUser;

      // اگر اینترنت قطع است یا مربی هنوز وارد حساب خود نشده است، سینک را متوقف کن
      if (client == null || currentUser == null) {
        _isSyncing = false;
        return const SyncSummary(
          success: false,
          message:
              'حالت آفلاین فعال است. تمام اطلاعات در حافظه امن گوشی ذخیره شدهاند.',
        );
      }

      // ۱. پینگ Heartbeat برای جلوگیری از Pause شدن پروژه در پلن رایگان Supabase
      await client.from('app_heartbeat').upsert({
        'id': 1,
        'last_ping': DateTime.now().toUtc().toIso8601String(),
      });

      // ۲. ارسال ورزشکاران آفلاین به Supabase
      final pendingAthletes = _db.getPendingSyncAthletes();
      for (final athlete in pendingAthletes) {
        final payload = athlete.toSupabaseJson()
          ..['coach_id'] = currentUser.id;
        await client.from('athletes').upsert(payload);
        _db.markRecordSynced('athletes', athlete.id);
      }

      // ۳. ارسال سایزگیریهای آفلاین به Supabase
      final pendingLogs = _db.getPendingSyncMeasurements();
      for (final log in pendingLogs) {
        final payload = log.toSupabaseJson()..['coach_id'] = currentUser.id;
        await client.from('measurement_logs').upsert(payload);
        _db.markRecordSynced('measurement_logs', log.id);
      }

      // ۴. ارسال برنامههای تمرینی/غذایی/مالی و قالبها به Supabase
      final pendingPrograms = _db.getPendingSyncPrograms();
      for (final prog in pendingPrograms) {
        final payload = prog.toSupabaseJson()..['coach_id'] = currentUser.id;
        await client.from('programs').upsert(payload);
        _db.markRecordSynced('programs', prog.id);
      }

      // ۵. ارسال پیامهای چت متنی آفلاین به Supabase
      final pendingChats = _db.getPendingSyncChatMessages();
      for (final chat in pendingChats) {
        final payload = chat.toSupabaseJson()..['coach_id'] = currentUser.id;
        await client.from('chat_messages').upsert(payload);
        _db.markRecordSynced('chat_messages', chat.id);
      }

      // ۶. ارسال لاگهای تمرین و آب مصرفی آفلاین به Supabase
      final pendingWorkoutLogs = _db.getPendingSyncWorkoutLogs();
      for (final wl in pendingWorkoutLogs) {
        final payload = wl.toSupabaseJson();
        await client.from('athlete_workout_logs').upsert(payload);
        _db.markRecordSynced('athlete_workout_logs', wl.id);
      }

      // ۷. ارسال فقط حرکات، غذاها و مکملهای «سفارشی» مربی (جلوگیری از تداخل آیتمهای پیشفرض بین مربیان)
      final customMoves = _db.getCustomExercisesOnly();
      for (final m in customMoves) {
        await client.from('exercises_catalog').upsert({
          'id': m.id,
          'coach_id': currentUser.id,
          'name_fa': m.nameFa,
          'name_en': m.nameEn,
          'target_muscle': m.targetMuscle,
          'equipment': m.equipment,
          'image_start_url': m.imageStartUrl,
          'image_end_url': m.imageEndUrl,
          'contraindicated_injuries': m.contraindicatedInjuries,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // فقط غذاهایی که شناسه آنها با 'food_' شروع نمیشود (یعنی مربی خودش ساخته است)
      final customFoods = _db
          .getFoodsCatalog()
          .where((f) => !(f['id'] ?? '').startsWith('food_'));
      for (final f in customFoods) {
        await client.from('custom_foods_catalog').upsert({
          'id': f['id'],
          'coach_id': currentUser.id,
          'name_fa': f['nameFa'],
          'name_en': f['nameEn'],
          'unit_fa': f['unitFa'],
          'unit_en': f['unitEn'],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // فقط مکملهایی که جزو ۸ مکمل پیشفرض اولیه نیستند
      final defaultSuppIds =
          SeedCatalogData.supplementCatalog.map((e) => e['id']).toSet();
      final customSupps = _db
          .getSupplementsCatalog()
          .where((s) => !defaultSuppIds.contains(s['id']));
      for (final s in customSupps) {
        await client.from('custom_supplements_catalog').upsert({
          'id': s['id'],
          'coach_id': currentUser.id,
          'name_fa': s['nameFa'],
          'name_en': s['nameEn'],
          'dosage_fa': s['defaultDosageFa'],
          'dosage_en': s['defaultDosageEn'],
          'timing_fa': s['defaultTimingFa'],
          'timing_en': s['defaultTimingEn'],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // ۶. بازیابی کامل از کلود در صورتی که دیتابیس گوشی خالی باشد (نصب روی گوشی جدید)
      if (_db.getAllActiveAthletes().isEmpty) {
        await _pullFromCloudIfLocalEmpty();
      }

      _isSyncing = false;
      return SyncSummary(
        syncedAthletes: pendingAthletes.length,
        syncedMeasurements: pendingLogs.length,
        syncedPrograms: pendingPrograms.length,
        success: true,
        message:
            'همگامسازی ابری کامل شد (${pendingAthletes.length} شاگرد، ${pendingPrograms.length} برنامه).',
      );
    } catch (e) {
      debugPrint('Supabase Sync Notice: $e');
      _isSyncing = false;
      return const SyncSummary(
        success: false,
        message: 'کار در حالت آفلاین ادامه دارد (اطلاعات در گوشی امن است).',
      );
    }
  }

  Future<void> _pullFromCloudIfLocalEmpty() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;

    // ۱. بازیابی حرکات سفارشی مربی
    final remoteMoves = await client.from('exercises_catalog').select();
    for (final r in remoteMoves) {
      _db.addCustomExercise(ExerciseSeedItem(
        id: r['id'] as String,
        nameFa: r['name_fa'] as String? ?? '',
        nameEn: r['name_en'] as String? ?? '',
        targetMuscle: r['target_muscle'] as String? ?? 'chest',
        equipment: r['equipment'] as String? ?? 'custom',
        imageStartUrl: r['image_start_url'] as String? ?? '',
        imageEndUrl: r['image_end_url'] as String? ?? '',
      ));
    }

    // ۲. بازیابی ورزشکاران
    final remoteAthletes = await client
        .from('athletes')
        .select()
        .eq('is_deleted', false)
        .order('updated_at', ascending: false);

    for (final row in remoteAthletes) {
      final rawTags = row['injury_tags'];
      final List<String> parsedTags = rawTags is String
          ? List<String>.from(jsonDecode(rawTags))
          : List<String>.from(rawTags ?? []);

      final athlete = AthleteEntity(
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
        isDeleted: false,
        syncStatus: 'synced',
      );
      _db.upsertAthlete(athlete);
    }

    // ۳. بازیابی تاریخچه سایزگیریها و نمودارها (Measurement Logs)
    final remoteLogs = await client
        .from('measurement_logs')
        .select()
        .order('recorded_at', ascending: true);

    for (final row in remoteLogs) {
      final log = MeasurementLogEntity(
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
        syncStatus: 'synced',
      );
      _db.insertMeasurementLog(log);
    }

    // ۴. بازیابی برنامهها و قالبها
    final remotePrograms = await client.from('programs').select();
    for (final row in remotePrograms) {
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

      final prog = FullProgramEntity(
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
        syncStatus: 'synced',
      );
      _db.upsertProgram(prog);
    }

    // ۵. بازیابی پیامهای چت
    final remoteChats = await client
        .from('chat_messages')
        .select()
        .order('created_at', ascending: true);
    for (final row in remoteChats) {
      _db.insertChatMessage(ChatMessageEntity(
        id: row['id'] as String,
        athleteId: row['athlete_id'] as String,
        senderRole: row['sender_role'] as String? ?? 'coach',
        messageText: row['message_text'] as String? ?? '',
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        syncStatus: 'synced',
      ));
    }
  }
}
