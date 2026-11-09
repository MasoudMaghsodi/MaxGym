import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../local/app_database.dart';
import '../local/database_models.dart';

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
      if (client == null) {
        _isSyncing = false;
        return const SyncSummary(
          success: false,
          message:
              'حالت آفلاین فعال است. تمام اطلاعات در حافظه امن گوشی ذخیره شدهاند.',
        );
      }

      // ۱. ارسال پینگ Heartbeat برای جلوگیری از Pause شدن پروژه در پلن رایگان Supabase
      await client.from('app_heartbeat').upsert({
        'id': 1,
        'last_ping': DateTime.now().toUtc().toIso8601String(),
      });

      // ۲. ارسال ورزشکاران آفلاین به Supabase (Push Athletes)
      final pendingAthletes = _db.getPendingSyncAthletes();
      for (final athlete in pendingAthletes) {
        await client.from('athletes').upsert(athlete.toSupabaseJson());
        _db.markRecordSynced('athletes', athlete.id);
      }

      // ۳. ارسال سایزگیریهای آفلاین به Supabase (Push Measurements)
      final pendingLogs = _db.getPendingSyncMeasurements();
      for (final log in pendingLogs) {
        await client.from('measurement_logs').upsert(log.toSupabaseJson());
        _db.markRecordSynced('measurement_logs', log.id);
      }

      // ۴. ارسال برنامههای تمرینی/غذایی/مالی به Supabase (Push Programs)
      final pendingPrograms = _db.getPendingSyncPrograms();
      for (final prog in pendingPrograms) {
        await client.from('programs').upsert(prog.toSupabaseJson());
        _db.markRecordSynced('programs', prog.id);
      }

      // ۵. بازیابی ابری (Cloud Pull) در صورتی که دیتابیس گوشی خالی باشد
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
            'همگامسازی ابری با موفقیت انجام شد (${pendingAthletes.length} شاگرد، ${pendingPrograms.length} برنامه).',
      );
    } catch (e) {
      debugPrint('Supabase Sync Error: $e');
      _isSyncing = false;
      return const SyncSummary(
        success: false,
        message: 'کار در حالت آفلاین ادامه دارد (عدم ارتباط با سرور ابری).',
      );
    }
  }

  Future<void> _pullFromCloudIfLocalEmpty() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;

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
  }
}
