import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  bool _hasDownloadedGlobal800Catalog = false;

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

  Future<void> ensureGlobal800ExerciseLibraryLoaded() async {
    if (_hasDownloadedGlobal800Catalog) return;
    if (_db.getExercisesCatalog().length > 200) {
      _hasDownloadedGlobal800Catalog = true;
      return;
    }

    if (kIsWeb) return;

    try {
      final httpClient = HttpClient();
      final req = await httpClient
          .getUrl(Uri.parse(SeedCatalogData.global800ExercisesJsonUrl))
          .timeout(const Duration(seconds: 10));
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final decoded = jsonDecode(body) as List<dynamic>;
        _db.importGlobal800ExercisesBatch(decoded);
        _hasDownloadedGlobal800Catalog = true;
      }
    } catch (_) {}
  }

  Future<SyncSummary> syncAllPendingData() async {
    if (_isSyncing) {
      return const SyncSummary(
          success: false, message: 'در حال همگامسازی...');
    }
    _isSyncing = true;

    try {
      unawaited(ensureGlobal800ExerciseLibraryLoaded());

      if (!SupabaseConfig.isInitialized) {
        await SupabaseConfig.initializeSafely();
      }
      final client = SupabaseConfig.clientOrNull;
      final currentUser = client?.auth.currentUser;

      if (client == null || currentUser == null) {
        _isSyncing = false;
        return const SyncSummary(
          success: false,
          message:
              'حالت آفلاین فعال است. تمام اطلاعات در حافظه امن دستگاه ذخیره شدهاند.',
        );
      }

      await client.from('app_heartbeat').upsert({
        'id': 1,
        'last_ping': DateTime.now().toUtc().toIso8601String(),
      });

      // ۱. ارسال دستهای (Batch Upsert) ورزشکاران
      final pendingAthletes = _db.getPendingSyncAthletes();
      if (pendingAthletes.isNotEmpty) {
        final batch = pendingAthletes
            .map((a) => a.toSupabaseJson()..['coach_id'] = currentUser.id)
            .toList();
        await client.from('athletes').upsert(batch);
        for (final athlete in pendingAthletes) {
          _db.markRecordSynced('athletes', athlete.id);
        }
      }

      // ۲. ارسال دستهای سایزگیریها
      final pendingLogs = _db.getPendingSyncMeasurements();
      if (pendingLogs.isNotEmpty) {
        final batch = pendingLogs
            .map((l) => l.toSupabaseJson()..['coach_id'] = currentUser.id)
            .toList();
        await client.from('measurement_logs').upsert(batch);
        for (final log in pendingLogs) {
          _db.markRecordSynced('measurement_logs', log.id);
        }
      }

      // ۳. ارسال دستهای برنامهها
      final pendingPrograms = _db.getPendingSyncPrograms();
      if (pendingPrograms.isNotEmpty) {
        final batch = pendingPrograms
            .map((p) => p.toSupabaseJson()..['coach_id'] = currentUser.id)
            .toList();
        await client.from('programs').upsert(batch);
        for (final prog in pendingPrograms) {
          _db.markRecordSynced('programs', prog.id);
        }
      }

      // ۴. ارسال دستهای پیامهای چت
      final pendingChats = _db.getPendingSyncChatMessages();
      if (pendingChats.isNotEmpty) {
        final batch = pendingChats
            .map((m) => m.toSupabaseJson()..['coach_id'] = currentUser.id)
            .toList();
        await client.from('chat_messages').upsert(batch);
        for (final msg in pendingChats) {
          _db.markRecordSynced('chat_messages', msg.id);
        }
      }

      // ۵. ارسال لاگهای تمرین
      final pendingWorkoutLogs = _db.getPendingSyncWorkoutLogs();
      if (pendingWorkoutLogs.isNotEmpty) {
        final batch =
            pendingWorkoutLogs.map((wl) => wl.toSupabaseJson()).toList();
        await client.from('athlete_workout_logs').upsert(batch);
        for (final wl in pendingWorkoutLogs) {
          _db.markRecordSynced('athlete_workout_logs', wl.id);
        }
      }

      // ۶. سینک بانکهای سفارشی مربی
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

      final remoteWorkoutLogs = await client
          .from('athlete_workout_logs')
          .select()
          .order('logged_at', ascending: false)
          .limit(100);
      for (final r in remoteWorkoutLogs) {
        final rawSets = r['completed_sets_json'];
        final Map<String, String> setsMap = rawSets is String
            ? Map<String, String>.from(jsonDecode(rawSets))
            : Map<String, String>.from(rawSets ?? {});
        _db.upsertWorkoutLog(AthleteWorkoutLogEntity(
          id: r['id'] as String,
          athleteId: r['athlete_id'] as String,
          programId: r['program_id'] as String,
          dayNumber: (r['day_number'] as num?)?.toInt() ?? 1,
          exerciseWeightsKg: setsMap,
          waterGlasses: (r['water_glasses'] as num?)?.toInt() ?? 0,
          sessionRpe: (r['session_rpe'] as num?)?.toInt() ?? 8,
          athleteFeedback: r['athlete_feedback'] as String? ?? '',
          loggedAt: DateTime.parse(r['logged_at'] as String).toLocal(),
        ));
      }

      if (_db.getAllActiveAthletes().isEmpty) {
        await _pullFromCloudWithPagination(currentUser.id);
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
        message: 'کار در حالت آفلاین ادامه دارد (اطلاعات در دستگاه امن است).',
      );
    }
  }

  Future<void> _pullFromCloudWithPagination(String coachId) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;

    final remoteMoves = await client
        .from('exercises_catalog')
        .select()
        .eq('coach_id', coachId);
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

    final remoteAthletes = await client
        .from('athletes')
        .select()
        .eq('coach_id', coachId)
        .eq('is_deleted', false)
        .order('updated_at', ascending: false)
        .range(0, 999);

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

    int offset = 0;
    const pageSize = 1000;
    while (true) {
      final remoteLogs = await client
          .from('measurement_logs')
          .select()
          .eq('coach_id', coachId)
          .order('recorded_at', ascending: true)
          .range(offset, offset + pageSize - 1);

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

      if (remoteLogs.length < pageSize) break;
      offset += pageSize;
    }

    final remotePrograms = await client
        .from('programs')
        .select()
        .eq('coach_id', coachId)
        .range(0, 999);
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

    final remoteChats = await client
        .from('chat_messages')
        .select()
        .eq('coach_id', coachId)
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
