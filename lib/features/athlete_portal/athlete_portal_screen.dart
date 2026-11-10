import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/cache/smart_cache_manager.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/branding_provider.dart';
import '../../core/utils/number_parser.dart';
import '../../core/widgets/maxgym_3d_widgets.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_models.dart';
import '../../data/local/seed_catalog_data.dart';
import '../athletes/domain/scientific_bio_calculator.dart';
import '../auth/security_gate_screen.dart';
import '../pdf_export/pdf_export_engine.dart';

class AthletePortalScreen extends ConsumerStatefulWidget {
  final AthleteEntity initialAthlete;
  const AthletePortalScreen({super.key, required this.initialAthlete});

  @override
  ConsumerState<AthletePortalScreen> createState() =>
      _AthletePortalScreenState();
}

class _AthletePortalScreenState extends ConsumerState<AthletePortalScreen> {
  late AthleteEntity _athlete;
  int _selectedTabIndex = 0;
  int _selectedDayIdx = 0;

  final Map<String, String> _loggedWeights = {};
  final Set<String> _completedExerciseIds = {};
  int _waterGlassesToday = 0;

  Timer? _restTimer;
  int _remainingRestSeconds = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _programsRealtimeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _athleteRealtimeSub;

  @override
  void initState() {
    super.initState();
    _athlete = widget.initialAthlete;
    final weekday = DateTime.now().weekday;
    _selectedDayIdx = (weekday + 1) % 7;
    _startRealtimeProgramAndProfileSync();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _programsRealtimeSub?.cancel();
    _athleteRealtimeSub?.cancel();
    super.dispose();
  }

  void _startRealtimeProgramAndProfileSync() {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;
    final db = ref.read(appDatabaseProvider);

    _programsRealtimeSub = client
        .from('programs')
        .stream(primaryKey: ['id'])
        .eq('athlete_id', _athlete.id)
        .listen((rows) {
      for (final pRow in rows) {
        if (pRow['is_template'] == true) continue;
        final rawDays = pRow['days_json'];
        final decodedDays =
            (rawDays is String ? jsonDecode(rawDays) : rawDays) as List<dynamic>;
        final rawMeals = pRow['diet_meals_json'];
        final mealsStr = rawMeals is String ? rawMeals : jsonEncode(rawMeals);
        final rawSupps = pRow['supplements_json'];
        final suppsStr = rawSupps is String ? rawSupps : jsonEncode(rawSupps);

        db.upsertProgram(FullProgramEntity(
          id: pRow['id'] as String,
          athleteId: _athlete.id,
          title: pRow['title'] as String? ?? '',
          startDate: DateTime.parse(pRow['start_date'] as String).toLocal(),
          durationWeeks: (pRow['duration_weeks'] as num?)?.toInt() ?? 4,
          days: decodedDays
              .map((e) => WorkoutDayPlan.fromJson(e as Map<String, dynamic>))
              .toList(),
          dietMeals: DietMealSlot.decodeList(mealsStr),
          waterLiters: (pRow['water_liters'] as num?)?.toDouble() ?? 3.5,
          supplements: SupplementPrescriptionItem.decodeList(suppsStr),
          updatedAt: DateTime.now(),
          syncStatus: 'synced',
        ));
      }
      if (mounted) setState(() {});
    }, onError: (_) {});

    _athleteRealtimeSub = client
        .from('athletes')
        .stream(primaryKey: ['id'])
        .eq('id', _athlete.id)
        .listen((rows) {
      if (rows.isNotEmpty && mounted) {
        final r = rows.first;
        final updated = AthleteEntity(
          id: r['id'] as String,
          firstName: r['first_name'] as String? ?? _athlete.firstName,
          lastName: r['last_name'] as String? ?? _athlete.lastName,
          phone: r['phone'] as String? ?? _athlete.phone,
          email: r['email'] as String? ?? _athlete.email,
          accessCode: r['access_code'] as String? ?? _athlete.accessCode,
          gender: r['gender'] as String? ?? _athlete.gender,
          age: (r['age'] as num?)?.toInt() ?? _athlete.age,
          heightCm: (r['height_cm'] as num?)?.toDouble() ?? _athlete.heightCm,
          weightKg: (r['weight_kg'] as num?)?.toDouble() ?? _athlete.weightKg,
          fitnessGoal: r['fitness_goal'] as String? ?? _athlete.fitnessGoal,
          injuryTags: _athlete.injuryTags,
          createdAt: _athlete.createdAt,
          updatedAt: DateTime.now(),
          syncStatus: 'synced',
        );
        db.upsertAthlete(updated);
        setState(() => _athlete = updated);
      }
    }, onError: (_) {});
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() => _remainingRestSeconds = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingRestSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remainingRestSeconds = 0);
      } else {
        setState(() => _remainingRestSeconds--);
      }
    });
  }

  Widget _buildNeonImagePlaceholder(Color primary) {
    return Container(
      color: const Color(0xFF0B100D),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withOpacity(0.12),
              border: Border.all(color: primary.withOpacity(0.35)),
            ),
            child: Icon(LucideIcons.dumbbell, size: 26, color: primary),
          ),
          const SizedBox(height: 6),
          Text(
            'MAX GYM MOTION',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: primary.withOpacity(0.65),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenExerciseImage(
      BuildContext context, WorkoutItemEntity ex, bool isFa) {
    final cleanFa = SeedCatalogData.extractCleanPersianTitle(
            ex.exerciseNameFa, ex.exerciseNameEn)
        .toCleanPersian();
    final primary = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0E1411),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: primary.withOpacity(0.5), width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isFa ? cleanFa : ex.exerciseNameEn,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    ex.exerciseNameEn,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ),
                const SizedBox(height: 14),
                InteractiveViewer(
                  child: Column(
                    children: [
                      if (ex.imageStartUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            cacheManager: SmartExerciseCacheManager.instance,
                            imageUrl: ex.imageStartUrl,
                            height: 210,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) =>
                                _buildNeonImagePlaceholder(primary),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (ex.imageEndUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            cacheManager: SmartExerciseCacheManager.instance,
                            imageUrl: ex.imageEndUrl,
                            height: 210,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) =>
                                _buildNeonImagePlaceholder(primary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isFa ? 'بستن تصویر' : 'Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitDailyWorkoutLog(FullProgramEntity program) async {
    final db = ref.read(appDatabaseProvider);
    final isFa = AppStrings.of(context).isFa;
    final log = AthleteWorkoutLogEntity(
      id: const Uuid().v4(),
      athleteId: _athlete.id,
      programId: program.id,
      dayNumber: _selectedDayIdx + 1,
      exerciseWeightsKg: _loggedWeights,
      waterGlasses: _waterGlassesToday,
      sessionRpe: 8,
      athleteFeedback: 'Completed via Athlete Portal',
      loggedAt: DateTime.now(),
    );

    db.upsertWorkoutLog(log);

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        try {
          await client.rpc('athlete_submit_workout_log', params: {
            'p_id': log.id,
            'p_athlete_id': _athlete.id,
            'p_access_code': _athlete.accessCode,
            'p_program_id': program.id,
            'p_day_number': log.dayNumber,
            'p_completed_sets_json': log.exerciseMaxWeights,
            'p_water_glasses': log.waterGlasses,
            'p_session_rpe': log.sessionRpe,
            'p_athlete_feedback': log.athleteFeedback,
          });
        } catch (_) {
          await client
              .from('athlete_workout_logs')
              .upsert(log.toSupabaseJson());
        }
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFa
              ? '🏆 آفرین! رکوردها و گزارش تمرین امروزت به صورت زنده برای مربی ارسال شد.'
              : '🏆 Awesome! Today\'s workout & PRs sent live to your coach.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final db = ref.watch(appDatabaseProvider);

    if (!_athlete.isProfileComplete) {
      return _MandatoryAthleteProfileCompletionGate(
        athlete: _athlete,
        onCompleted: (updated) {
          setState(() => _athlete = updated);
        },
      );
    }

    final programs = db.getProgramsForAthlete(_athlete.id);
    final activeProgram = programs.isNotEmpty ? programs.first : null;
    final measurements = db.getMeasurementsForAthlete(_athlete.id);

    final bio = ScientificBioCalculator.analyze(
      gender: _athlete.gender,
      age: _athlete.age,
      heightCm: _athlete.heightCm,
      weightKg: _athlete.weightKg,
      fitnessGoal: _athlete.fitnessGoal,
      waistCm: measurements.isNotEmpty ? measurements.last.waistCm : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _athlete.fullName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'LIVE • 🔥 ${bio.targetCalories} kcal | 🥩 ${bio.proteinGrams}g P',
                      style: TextStyle(
                        fontSize: 11,
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_remainingRestSeconds > 0)
            GestureDetector(
              onTap: () => setState(() => _remainingRestSeconds = 0),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning.withOpacity(0.35),
                      AppColors.danger.withOpacity(0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warning, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '⏱ ${_remainingRestSeconds}s',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
            ),
          if (activeProgram != null)
            IconButton(
              tooltip: isFa ? 'دانلود PDF برنامه من' : 'Download PDF',
              icon: Icon(LucideIcons.fileDown, color: primary),
              onPressed: () {
                PdfExportEngine.generateAndShareProgramPdf(
                  context: context,
                  branding: ref.read(brandingProvider),
                  athlete: _athlete,
                  program: activeProgram,
                  measurements: measurements,
                );
              },
            ),
          IconButton(
            tooltip: isFa ? 'خروج' : 'Sign Out',
            icon: const Icon(LucideIcons.logOut, color: AppColors.danger),
            onPressed: () => ref.read(securityGateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildInteractiveWorkoutTab(activeProgram, bio, isFa, theme),
              _buildInteractiveNutritionAndWaterTab(
                  activeProgram, bio, isFa, theme),
              PureTextChatView(
                athlete: _athlete,
                currentSenderRole: 'athlete',
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (i) => setState(() => _selectedTabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.flame),
            label: isFa ? 'باشگاه و تمرین' : 'Workout',
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.apple),
            label: isFa ? 'تغذیه و مکمل' : 'Nutrition',
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.messageSquare),
            label: isFa ? 'چت زنده مربی' : 'Live Chat',
          ),
        ],
      ),
    );
  }

  /// رادار مهندسی تلمتری فشار بیومکانیکی عضلات (جایگزین حرفهای آدمک کارتونی)
  Widget _buildBiometricMuscleTelemetryHud(
      WorkoutDayPlan activeDay, bool isFa, Color primary) {
    final totalSets =
        activeDay.exercises.fold<int>(0, (sum, ex) => sum + ex.sets.length);
    final Map<String, int> muscleSetCounts = {};
    for (final ex in activeDay.exercises) {
      final m = ex.targetMuscle.isNotEmpty
          ? ex.targetMuscle
          : (activeDay.targetMuscles.isNotEmpty
              ? activeDay.targetMuscles.first
              : 'chest');
      muscleSetCounts[m] = (muscleSetCounts[m] ?? 0) + ex.sets.length;
    }
    for (final tm in activeDay.targetMuscles) {
      muscleSetCounts.putIfAbsent(tm, () => 3);
    }

    const muscleLabelsFa = {
      'chest': 'سینه (Pectorals)',
      'back': 'زیربغل و لت (Lats)',
      'shoulders': 'سرشانه (Deltoids)',
      'biceps': 'جلوبازو و ساعد (Biceps)',
      'triceps': 'پشتبازو (Triceps)',
      'legs': 'چهارسر و همسترینگ (Legs)',
      'abs': 'شکم و میانتنه (Core)',
      'calves': 'ساق پا (Calves)',
    };

    return MaxGymGlassCard(
      accentColor: primary,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(LucideIcons.activity, color: primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFa
                            ? 'تلمتری بیومکانیک و فشار عضلانی جلسه'
                            : 'BIOMETRIC MUSCLE LOAD TELEMETRY',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primary.withOpacity(0.45)),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${activeDay.exercises.length} MOVES • $totalSets SETS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...muscleSetCounts.entries.map((entry) {
            final ratio =
                (entry.value / (totalSets > 0 ? totalSets : 1)).clamp(0.25, 1.0);
            final label = isFa
                ? (muscleLabelsFa[entry.key] ?? entry.key.toUpperCase())
                : entry.key.toUpperCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${entry.value} SETS ACTIVE • ${(ratio * 100).round()}% LOAD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: Colors.white10,
                      color: primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInteractiveWorkoutTab(FullProgramEntity? program,
      BioAnalysisResult bio, bool isFa, ThemeData theme) {
    final primary = theme.colorScheme.primary;

    if (program == null || program.days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: MaxGymGlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, size: 56, color: primary),
                const SizedBox(height: 16),
                Text(
                  isFa
                      ? 'در انتظار ارسال برنامه از سمت مربی...\n(به محض ثبت برنامه توسط مربی، به صورت زنده اینجا ظاهر میشود!)'
                      : 'Waiting for your coach to assign a plan (Updates Live!).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final safeIdx = _selectedDayIdx.clamp(0, program.days.length - 1);
    final activeDay = program.days[safeIdx];
    final totalMoves = activeDay.exercises.length;
    final doneMoves = activeDay.exercises
        .where((e) => _completedExerciseIds.contains(e.id))
        .length;
    final progress = totalMoves > 0 ? doneMoves / totalMoves : 0.0;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        MaxGymGlassCard(
          accentColor: primary,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      program.title.toCleanPersian(),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${(progress * 100).round()}% DONE',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: program.days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final d = program.days[i];
              final selected = i == safeIdx;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? primary : const Color(0xFF151C18),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected ? primary : Colors.white12,
                      width: 1.4,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isFa ? d.dayNameFa.toCleanPersian() : d.dayNameEn,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),

        if (activeDay.isRestDay)
          MaxGymGlassCard(
            accentColor: Colors.cyanAccent,
            padding: const EdgeInsets.all(38),
            child: Column(
              children: [
                const Icon(LucideIcons.moon,
                    size: 52, color: Colors.cyanAccent),
                const SizedBox(height: 14),
                Text(
                  isFa
                      ? 'امروز روز استراحت، ریکاوری و رشد عضلات شماست! 💤💧'
                      : 'Active Recovery & Muscle Growth Day! 💤💧',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          )
        else ...[
          _buildBiometricMuscleTelemetryHud(activeDay, isFa, primary),
          const SizedBox(height: 18),
          ...List.generate(activeDay.exercises.length, (idx) {
            final ex = activeDay.exercises[idx];
            final isDone = _completedExerciseIds.contains(ex.id);
            final restSec =
                ex.sets.isNotEmpty ? ex.sets.first.restSeconds : 60;

            final cleanPersianTitle = SeedCatalogData.extractCleanPersianTitle(
                    ex.exerciseNameFa, ex.exerciseNameEn)
                .toCleanPersian();

            return MaxGymGlassCard(
              margin: const EdgeInsets.only(bottom: 18),
              padding: EdgeInsets.zero,
              accentColor: isDone
                  ? AppColors.success
                  : (ex.supersetGroupId != null ? AppColors.warning : primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ex.imageStartUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () =>
                          _showFullScreenExerciseImage(context, ex, isFa),
                      child: Container(
                        height: 185,
                        decoration: const BoxDecoration(
                          color: Color(0xFF090D0B),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(23)),
                        ),
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: CachedNetworkImage(
                                          cacheManager:
                                              SmartExerciseCacheManager.instance,
                                          imageUrl: ex.imageStartUrl,
                                          fit: BoxFit.contain,
                                          placeholder: (_, __) =>
                                              _buildNeonImagePlaceholder(
                                                  primary),
                                          errorWidget: (_, __, ___) =>
                                              _buildNeonImagePlaceholder(
                                                  primary),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.white24),
                                          ),
                                          child: Text(
                                            isFa ? 'شروع حرکت' : 'START',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white70),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1.5, color: Colors.white12),
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: CachedNetworkImage(
                                          cacheManager:
                                              SmartExerciseCacheManager.instance,
                                          imageUrl: ex.imageEndUrl.isNotEmpty
                                              ? ex.imageEndUrl
                                              : ex.imageStartUrl,
                                          fit: BoxFit.contain,
                                          placeholder: (_, __) =>
                                              _buildNeonImagePlaceholder(
                                                  primary),
                                          errorWidget: (_, __, ___) =>
                                              _buildNeonImagePlaceholder(
                                                  primary),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color:
                                                    primary.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            isFa ? 'انقباض / پایان' : 'FINISH',
                                            style: TextStyle(
                                                fontSize: 10, color: primary),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(LucideIcons.maximize2,
                                    size: 15, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: primary.withOpacity(0.6),
                                    width: 1.5),
                              ),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '0${idx + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (ex.supersetGroupId != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.warning.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          '🔗 SUPERSET (${ex.supersetGroupId})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    isFa
                                        ? cleanPersianTitle
                                        : ex.exerciseNameEn,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (isFa && ex.exerciseNameEn.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        ex.exerciseNameEn,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: primary.withOpacity(0.85),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (ex.coachNote.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        '📌 نکته مربی: ${ex.coachNote.toCleanPersian()}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: primary),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 1.25,
                              child: Checkbox(
                                value: isDone,
                                activeColor: AppColors.success,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _completedExerciseIds.add(ex.id);
                                      _startRestTimer(restSec);
                                    } else {
                                      _completedExerciseIds.remove(ex.id);
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ex.sets.map((s) {
                            return ActionChip(
                              avatar: Icon(LucideIcons.timer,
                                  size: 14, color: primary),
                              label: Text(
                                'ست ${s.setNumber}: ${s.reps} | تمپو: ${s.tempo}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _startRestTimer(s.restSeconds),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (val) {
                                  _loggedWeights[ex.id] = val.toEnglishDigits();
                                },
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: isFa
                                      ? 'ثبت رکورد وزنه (مثلاً 85 kg)'
                                      : 'Log weight lifted (kg)',
                                  prefixIcon:
                                      const Icon(LucideIcons.trophy, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () => _startRestTimer(restSec),
                              icon: const Icon(LucideIcons.timer, size: 16),
                              label: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text('${restSec}s'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _submitDailyWorkoutLog(program),
            icon: const Icon(LucideIcons.award),
            label: Text(isFa
                ? 'ثبت نهایی تمرین امروز و ارسال زنده برای مربی'
                : 'Finish & Send Live to Coach'),
          ),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  Widget _buildInteractiveNutritionAndWaterTab(FullProgramEntity? program,
      BioAnalysisResult bio, bool isFa, ThemeData theme) {
    final targetGlasses =
        ((program?.waterLiters ?? bio.waterLiters) * 4).round();
    final primary = theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        MaxGymGlassCard(
          accentColor: Colors.lightBlueAccent,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isFa
                          ? '💧 آبرسانی بدن: $_waterGlassesToday از $targetGlasses لیوان'
                          : '💧 Hydration: $_waterGlassesToday / $targetGlasses Glasses',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _waterGlassesToday++),
                    icon: const Icon(LucideIcons.glassWater, size: 16),
                    label: Text(isFa ? '+۱ لیوان' : '+1 Glass'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_waterGlassesToday / targetGlasses).clamp(0.0, 1.0),
                  color: Colors.lightBlueAccent,
                  minHeight: 10,
                  backgroundColor: Colors.black38,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (program != null) ...[
          ...program.dietMeals.where((m) => m.items.isNotEmpty).map((meal) {
            return MaxGymGlassCard(
              margin: const EdgeInsets.only(bottom: 14),
              accentColor: primary,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFa ? meal.titleFa.toCleanPersian() : meal.titleEn,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: primary,
                    ),
                  ),
                  const Divider(height: 18, color: Colors.white12),
                  ...meal.items.map((item) {
                    final alts =
                        isFa ? item.alternativesFa : item.alternativesEn;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        isFa
                            ? '• ${item.foodNameFa.toCleanPersian()} (${item.amountFa.toCleanPersian()})${alts.isNotEmpty ? "\n   🔄 جایگزین: ${alts.join(" یا ").toCleanPersian()}" : ""}'
                            : '• ${item.foodNameEn} (${item.amountEn})${alts.isNotEmpty ? "\n   🔄 OR: ${alts.join(" / ")}" : ""}',
                        style: const TextStyle(height: 1.5),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          if (program.supplements.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...program.supplements.map((s) {
              return MaxGymGlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.pill, color: primary),
                  ),
                  title: Text(isFa ? s.nameFa.toCleanPersian() : s.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(isFa
                      ? '${s.dosageFa.toCleanPersian()} | ${s.timingFa.toCleanPersian()}'
                      : '${s.dosageEn} | ${s.timingEn}'),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }
}

class _MandatoryAthleteProfileCompletionGate extends ConsumerStatefulWidget {
  final AthleteEntity athlete;
  final void Function(AthleteEntity updated) onCompleted;

  const _MandatoryAthleteProfileCompletionGate({
    required this.athlete,
    required this.onCompleted,
  });

  @override
  ConsumerState<_MandatoryAthleteProfileCompletionGate> createState() =>
      _MandatoryAthleteProfileCompletionGateState();
}

class _MandatoryAthleteProfileCompletionGateState
    extends ConsumerState<_MandatoryAthleteProfileCompletionGate> {
  late TextEditingController _firstCtrl;
  late TextEditingController _lastCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.athlete;
    _firstCtrl = TextEditingController(text: a.firstName);
    _lastCtrl = TextEditingController(text: a.lastName);
    _phoneCtrl = TextEditingController(text: a.phone);
    _emailCtrl = TextEditingController(text: a.email);
    _ageCtrl = TextEditingController(text: a.age.toString());
    _heightCtrl = TextEditingController(text: a.heightCm.toStringAsFixed(0));
    _weightCtrl = TextEditingController(text: a.weightKg.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCompleteProfile() async {
    final isFa = AppStrings.of(context).isFa;
    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final phone = _phoneCtrl.text.toEnglishDigits();
    final email = _emailCtrl.text.trim();
    final age = _ageCtrl.text.toSafeInt() ?? 25;
    final height = _heightCtrl.text.toSafeDouble() ?? 175;
    final weight = _weightCtrl.text.toSafeDouble() ?? 75;

    if (first.isEmpty ||
        last.isEmpty ||
        phone.length < 8 ||
        !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFa
              ? 'لطفاً تمام فیلدها (نام، نام خانوادگی، موبایل و ایمیل معتبر) را کامل وارد کنید.'
              : 'Please complete all required fields including a valid email.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final updated = AthleteEntity(
      id: widget.athlete.id,
      firstName: first,
      lastName: last,
      phone: phone,
      email: email,
      accessCode: widget.athlete.accessCode,
      gender: widget.athlete.gender,
      age: age,
      heightCm: height,
      weightKg: weight,
      fitnessGoal: widget.athlete.fitnessGoal,
      injuryTags: widget.athlete.injuryTags,
      createdAt: widget.athlete.createdAt,
      updatedAt: DateTime.now(),
      syncStatus: 'synced',
    );

    ref.read(appDatabaseProvider).upsertAthlete(updated);

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        try {
          await client.rpc('athlete_complete_profile', params: {
            'p_athlete_id': updated.id,
            'p_access_code': updated.accessCode,
            'p_first_name': updated.firstName,
            'p_last_name': updated.lastName,
            'p_phone': updated.phone,
            'p_email': updated.email,
            'p_age': updated.age,
            'p_height_cm': updated.heightCm,
            'p_weight_kg': updated.weightKg,
          });
        } catch (_) {
          await client.from('athletes').update({
            'first_name': updated.firstName,
            'last_name': updated.lastName,
            'phone': updated.phone,
            'email': updated.email,
            'age': updated.age,
            'height_cm': updated.heightCm,
            'weight_kg': updated.weightKg,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', updated.id);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _saving = false);
      widget.onCompleted(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFa
            ? 'تکمیل یکباره پرونده ورزشی شما'
            : 'Complete Your Athlete Profile'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              MaxGymGlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isFa
                          ? 'ورزشکار عزیز، این فرم فقط در اولین ورود شما نمایش داده میشود. پس از تکمیل، میتوانید با ایمیل، شماره تماس یا کد اختصاصی خود وارد شوید:'
                          : 'Complete your profile once to unlock your portal:',
                      style:
                          const TextStyle(color: Colors.white70, height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstCtrl,
                            decoration: InputDecoration(
                                labelText: isFa ? 'نام *' : 'First Name *'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastCtrl,
                            decoration: InputDecoration(
                                labelText:
                                    isFa ? 'نام خانوادگی *' : 'Last Name *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isFa ? 'شماره تماس *' : 'Phone Number *',
                        prefixIcon: const Icon(LucideIcons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: isFa ? 'آدرس ایمیل *' : 'Email Address *',
                        prefixIcon: const Icon(LucideIcons.mail),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: isFa ? 'سن *' : 'Age *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _heightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText:
                                    isFa ? 'قد (cm) *' : 'Height (cm) *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _weightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText:
                                    isFa ? 'وزن (kg) *' : 'Weight (kg) *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveCompleteProfile,
                      icon: const Icon(LucideIcons.checkCircle2),
                      label: Text(isFa
                          ? 'ثبت دائمی و ورود به پنل ورزشکار'
                          : 'Save & Enter Portal'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PureTextChatView extends ConsumerStatefulWidget {
  final AthleteEntity athlete;
  final String currentSenderRole; // 'coach' | 'athlete'

  const PureTextChatView({
    super.key,
    required this.athlete,
    required this.currentSenderRole,
  });

  @override
  ConsumerState<PureTextChatView> createState() => _PureTextChatViewState();
}

class _PureTextChatViewState extends ConsumerState<PureTextChatView> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessageEntity> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeChatSub;

  @override
  void initState() {
    super.initState();
    _messages = ref
        .read(appDatabaseProvider)
        .getChatMessagesForAthlete(widget.athlete.id);
    _subscribeToRealtimeChatStream();
  }

  @override
  void dispose() {
    _realtimeChatSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _subscribeToRealtimeChatStream() {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;
    final db = ref.read(appDatabaseProvider);

    _realtimeChatSub = client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('athlete_id', widget.athlete.id)
        .order('created_at', ascending: true)
        .listen((rows) {
      for (final r in rows) {
        db.insertChatMessage(ChatMessageEntity(
          id: r['id'] as String,
          athleteId: r['athlete_id'] as String,
          senderRole: r['sender_role'] as String,
          messageText: r['message_text'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          syncStatus: 'synced',
        ));
      }
      if (mounted) {
        setState(() {
          _messages = db.getChatMessagesForAthlete(widget.athlete.id);
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }, onError: (_) {});
  }

  Future<void> _sendTextMessage() async {
    final text = _msgCtrl.text.toSanitizedText(maxLength: 500);
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final msg = ChatMessageEntity(
      id: const Uuid().v4(),
      athleteId: widget.athlete.id,
      senderRole: widget.currentSenderRole,
      messageText: text,
      createdAt: DateTime.now(),
    );

    final db = ref.read(appDatabaseProvider);
    db.insertChatMessage(msg);
    setState(() {
      _messages = db.getChatMessagesForAthlete(widget.athlete.id);
    });

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        await client.from('chat_messages').upsert(msg.toSupabaseJson());
        db.markRecordSynced('chat_messages', msg.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121815),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withOpacity(0.28)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isFa
                          ? 'چت آنلاین و زنده با ${widget.athlete.fullName}'
                          : 'Live Realtime Chat • ${widget.athlete.fullName}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        isFa
                            ? 'گفتگوی زنده آماده است. اولین پیام را ارسال کنید...'
                            : 'Live chat ready. Send a message...',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(18),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final m = _messages[i];
                        final isMe = m.senderRole == widget.currentSenderRole;
                        return Align(
                          alignment: isMe
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            constraints: const BoxConstraints(maxWidth: 360),
                            decoration: BoxDecoration(
                              gradient: isMe
                                  ? LinearGradient(
                                      colors: [
                                        primary.withOpacity(0.32),
                                        primary.withOpacity(0.14),
                                      ],
                                    )
                                  : null,
                              color: isMe ? null : const Color(0xFF171F1B),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                              border: Border.all(
                                color: isMe
                                    ? primary.withOpacity(0.65)
                                    : Colors.white12,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.messageText,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.4)),
                                const SizedBox(height: 6),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white60),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF121815),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLength: 500,
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        hintText: isFa
                            ? 'پیام خود را بنویسید...'
                            : 'Type a live message...',
                      ),
                      onSubmitted: (_) => _sendTextMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendTextMessage,
                    icon: const Icon(LucideIcons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
