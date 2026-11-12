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

      // ۰. حذف برنامهها یا قالبهایی که مربی در حالت محلی پاک کرده است (رفع باگ Zombie Programs)
      final deletedProgIds = _db.getPendingCloudDeleteProgramIds();
      for (final delId in deletedProgIds) {
        try {
          await client
              .from('programs')
              .delete()
              .eq('id', delId)
              .eq('coach_id', currentUser.id);
          _db.clearPendingCloudDeleteProgramId(delId);
        } catch (_) {}
      }

      // ۱. ارسال هوشمند ورزشکاران (با حفظ ایمیل، رمز عبور و وزن جدیدی که شاگرد در پرتال ثبت کرده)
      final pendingAthletes = _db.getPendingSyncAthletes();
      if (pendingAthletes.isNotEmpty) {
        final pendingIds = pendingAthletes.map((a) => a.id).toList();
        final remoteSnapshots = await client
            .from('athletes')
            .select()
            .inFilter('id', pendingIds);
        final remoteMap = <String, Map<String, dynamic>>{
          for (final r in remoteSnapshots) r['id'] as String: r,
        };

        final List<Map<String, dynamic>> batch = [];
        for (final localAth in pendingAthletes) {
          final payload = localAth.toSupabaseJson()
            ..['coach_id'] = currentUser.id;
          final remoteRow = remoteMap[localAth.id];

          // اگر شاگرد در پرتال خود پروفایلش را فعال کرده و مربی صرفاً ویرایش دیگری انجام داده، رمز و ایمیل شاگرد پاک نشود
          if (remoteRow != null) {
            final remoteBurned = remoteRow['is_code_burned'] as bool? ?? false;
            final remoteEmail = (remoteRow['email'] as String?) ?? '';
            final remotePass = (remoteRow['password_hash'] as String?) ?? '';
            final remoteStreak = (remoteRow['streak_days'] as num?)?.toInt() ?? 1;

            if (remoteBurned &&
                localAth.passwordHash.isEmpty &&
                remotePass.isNotEmpty) {
              payload['password_hash'] = remotePass;
              payload['is_code_burned'] = true;
            }
            if (localAth.email.isEmpty && remoteEmail.isNotEmpty) {
              payload['email'] = remoteEmail;
            }
            if (remoteStreak > localAth.streakDays) {
              payload['streak_days'] = remoteStreak;
            }
          }
          batch.add(payload);
        }

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

      // ۳. ارسال دستهای برنامهها و قالبها
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

      // ۵. ارسال لاگهای تمرین همراه با coach_id صریح
      final pendingWorkoutLogs = _db.getPendingSyncWorkoutLogs();
      if (pendingWorkoutLogs.isNotEmpty) {
        final batch = pendingWorkoutLogs
            .map((wl) => wl.toSupabaseJson()..['coach_id'] = currentUser.id)
            .toList();
        await client.from('athlete_workout_logs').upsert(batch);
        for (final wl in pendingWorkoutLogs) {
          _db.markRecordSynced('athlete_workout_logs', wl.id);
        }
      }

      // ۶. ارسال بانکهای سفارشی مربی
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

      // ۷. دریافت دوطرفه تغییرات ابری (Delta Pull)
      await _pullFromCloudWithPagination(currentUser.id);

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

    // ۱. دریافت حرکات، غذاها و مکملهای سفارشی مربی (رفع باگ ۷ و ۱۴)
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

    final remoteFoods = await client
        .from('custom_foods_catalog')
        .select()
        .eq('coach_id', coachId);
    for (final f in remoteFoods) {
      _db.addCustomFood(
        id: f['id'] as String,
        nameFa: f['name_fa'] as String? ?? '',
        nameEn: f['name_en'] as String? ?? '',
        unitFa: f['unit_fa'] as String? ?? '',
        unitEn: f['unit_en'] as String? ?? '',
      );
    }

    final remoteSupps = await client
        .from('custom_supplements_catalog')
        .select()
        .eq('coach_id', coachId);
    for (final s in remoteSupps) {
      _db.addCustomSupplement(
        id: s['id'] as String,
        nameFa: s['name_fa'] as String? ?? '',
        nameEn: s['name_en'] as String? ?? '',
        dosageFa: s['dosage_fa'] as String? ?? '',
        dosageEn: s['dosage_en'] as String? ?? '',
        timingFa: s['timing_fa'] as String? ?? '',
        timingEn: s['timing_en'] as String? ?? '',
      );
    }

    // ۲. دریافت و ادغام هوشمند شاگردان مربی
    final pendingLocalAthleteIds =
        _db.getPendingSyncAthletes().map((a) => a.id).toSet();

    final remoteAthletes = await client
        .from('athletes')
        .select()
        .eq('coach_id', coachId)
        .order('updated_at', ascending: false)
        .range(0, 999);

    final Set<String> coachOwnedAthleteIds = {};

    for (final row in remoteAthletes) {
      final athId = row['id'] as String;
      coachOwnedAthleteIds.add(athId);

      if (pendingLocalAthleteIds.contains(athId)) continue;

      final isDeletedRemote = row['is_deleted'] as bool? ?? false;
      final existingLocal = _db.getAthleteById(athId);

      if (isDeletedRemote) {
        if (existingLocal != null) {
          _db.softDeleteAthlete(athId);
          _db.markRecordSynced('athletes', athId);
        }
        continue;
      }

      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toLocal();
      if (existingLocal != null &&
          existingLocal.updatedAt.isAfter(remoteUpdatedAt)) {
        continue;
      }

      final rawTags = row['injury_tags'];
      final List<String> parsedTags = rawTags is String
          ? List<String>.from(jsonDecode(rawTags))
          : List<String>.from(rawTags ?? []);

      final athlete = AthleteEntity(
        id: athId,
        firstName: row['first_name'] as String? ?? '',
        lastName: row['last_name'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        email: row['email'] as String? ?? '',
        accessCode: row['access_code'] as String? ?? '',
        passwordHash:
            row['password_hash'] as String? ?? existingLocal?.passwordHash ?? '',
        isCodeBurned: row['is_code_burned'] as bool? ??
            existingLocal?.isCodeBurned ??
            false,
        streakDays: (row['streak_days'] as num?)?.toInt() ?? 1,
        gender: row['gender'] as String? ?? 'male',
        age: (row['age'] as num?)?.toInt() ?? 25,
        heightCm: (row['height_cm'] as num?)?.toDouble() ?? 175,
        weightKg: (row['weight_kg'] as num?)?.toDouble() ?? 75,
        fitnessGoal: row['fitness_goal'] as String? ?? 'lean_bulk',
        injuryTags: parsedTags,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        updatedAt: remoteUpdatedAt,
        isDeleted: false,
        syncStatus: 'synced',
      );
      _db.upsertAthlete(athlete);
    }

    for (final localAth in _db.getAllActiveAthletes()) {
      coachOwnedAthleteIds.add(localAth.id);
    }

    // ۳. دریافت تاریخچه سایزگیریها (شامل وزنهایی که شاگرد از پرتال ثبت کرده)
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

    // ۴. دریافت برنامهها و قالبها (با نادیده گرفتن مواردی که در صف حذف هستند)
    final pendingLocalProgramIds =
        _db.getPendingSyncPrograms().map((p) => p.id).toSet();
    final pendingDeletedIds = _db.getPendingCloudDeleteProgramIds();

    final remotePrograms = await client
        .from('programs')
        .select()
        .eq('coach_id', coachId)
        .range(0, 999);

    for (final row in remotePrograms) {
      final progId = row['id'] as String;
      if (pendingLocalProgramIds.contains(progId) ||
          pendingDeletedIds.contains(progId)) {
        continue;
      }

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
        id: progId,
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

    // ۵. دریافت پیامهای چت مختص همین مربی
    final remoteChats = await client
        .from('chat_messages')
        .select()
        .eq('coach_id', coachId)
        .order('created_at', ascending: true)
        .limit(500);

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

    // ۶. دریافت ایزوله لاگهای تمرین شاگردان همین مربی
    final remoteWorkoutLogs = await client
        .from('athlete_workout_logs')
        .select()
        .eq('coach_id', coachId)
        .order('logged_at', ascending: false)
        .limit(200);

    for (final r in remoteWorkoutLogs) {
      final athId = r['athlete_id'] as String? ?? '';
      if (!coachOwnedAthleteIds.contains(athId)) continue;

      final rawSets = r['completed_sets_json'];
      final Map<String, dynamic> setsMap = rawSets is String
          ? Map<String, dynamic>.from(jsonDecode(rawSets))
          : Map<String, dynamic>.from(rawSets ?? {});

      final logId = r['id'] as String;
      _db.upsertWorkoutLog(AthleteWorkoutLogEntity(
        id: logId,
        athleteId: athId,
        programId: r['program_id'] as String,
        dayNumber: (r['day_number'] as num?)?.toInt() ?? 1,
        exerciseWeightsKg: setsMap,
        waterGlasses: (r['water_glasses'] as num?)?.toInt() ?? 0,
        sessionRpe: (r['session_rpe'] as num?)?.toInt() ?? 8,
        athleteFeedback: r['athlete_feedback'] as String? ?? '',
        loggedAt: DateTime.parse(r['logged_at'] as String).toLocal(),
        syncStatus: 'synced',
      ));
    }
  }
}
