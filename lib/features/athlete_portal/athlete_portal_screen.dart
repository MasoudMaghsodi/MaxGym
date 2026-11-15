import '../../core/widgets/telegram_chat_and_notifications.dart';
import '../ai_copilot/maxbot_ai_assistant.dart';
import '../club_arena/club_arena_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Map<String, TextEditingController> _weightControllers = {};
  final Set<String> _completedExerciseIds = {};
  int _waterGlassesToday = 0;
  bool _isGymFocusMode = false; // حالت تمرکز بالا در حین تمرین (Transient Posture)

  Timer? _restTimer;
  int _remainingRestSeconds = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _programsRealtimeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _athleteRealtimeSub;
  Timer? _rpcPortalSyncTimer;

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
    _rpcPortalSyncTimer?.cancel();
    for (final ctrl in _weightControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _getOrInitWeightController(
      String exerciseId, double? ghostPreviousPr) {
    return _weightControllers.putIfAbsent(exerciseId, () {
      final initialText = _loggedWeights[exerciseId] ??
          (ghostPreviousPr != null && ghostPreviousPr > 0
              ? (ghostPreviousPr % 1 == 0
                  ? ghostPreviousPr.toInt().toString()
                  : ghostPreviousPr.toStringAsFixed(1))
              : '');
      if (initialText.isNotEmpty) {
        _loggedWeights[exerciseId] = initialText;
      }
      return TextEditingController(text: initialText);
    });
  }

  void _stepExerciseWeight(
      String exerciseId, double deltaKg, double? ghostPreviousPr) {
    HapticFeedback.selectionClick();
    final ctrl = _getOrInitWeightController(exerciseId, ghostPreviousPr);
    final currentVal =
        ctrl.text.toSafeDouble() ?? ghostPreviousPr ?? 20.0;
    final nextVal = (currentVal + deltaKg).clamp(0.0, 500.0);
    final formatted = nextVal % 1 == 0
        ? nextVal.toInt().toString()
        : nextVal.toStringAsFixed(1);
    setState(() {
      ctrl.text = formatted;
      _loggedWeights[exerciseId] = formatted;
    });
  }

  /// استخراج آخرین رکورد وزنه ثبتشده توسط شاگرد برای هر حرکت (Ghost PR Tracker)
  Map<String, double> _buildPreviousPrMap(LocalAppDatabase db) {
    final logs = db.getWorkoutLogsForAthlete(_athlete.id);
    final Map<String, double> prMap = {};
    for (final log in logs) {
      log.exerciseMaxWeights.forEach((exKey, weightVal) {
        if (weightVal > (prMap[exKey] ?? 0)) {
          prMap[exKey] = weightVal;
        }
      });
    }
    return prMap;
  }

  void _startRealtimeProgramAndProfileSync() {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;

    _refreshPortalBundleViaRpc();
    _rpcPortalSyncTimer?.cancel();
    _rpcPortalSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshPortalBundleViaRpc();
    });

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
        final updated = _athlete.copyWith(
          firstName: r['first_name'] as String? ?? _athlete.firstName,
          lastName: r['last_name'] as String? ?? _athlete.lastName,
          phone: r['phone'] as String? ?? _athlete.phone,
          email: r['email'] as String? ?? _athlete.email,
          accessCode: r['access_code'] as String? ?? _athlete.accessCode,
          isCodeBurned: r['is_code_burned'] as bool? ?? _athlete.isCodeBurned,
          streakDays:
              (r['streak_days'] as num?)?.toInt() ?? _athlete.streakDays,
          gender: r['gender'] as String? ?? _athlete.gender,
          age: (r['age'] as num?)?.toInt() ?? _athlete.age,
          heightCm: (r['height_cm'] as num?)?.toDouble() ?? _athlete.heightCm,
          weightKg: (r['weight_kg'] as num?)?.toDouble() ?? _athlete.weightKg,
          fitnessGoal: r['fitness_goal'] as String? ?? _athlete.fitnessGoal,
          updatedAt: DateTime.now(),
          syncStatus: 'synced',
        );
        db.upsertAthlete(updated);
        setState(() => _athlete = updated);
      }
    }, onError: (_) {});
  }

  Future<void> _refreshPortalBundleViaRpc() async {
    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null || !mounted) return;
      final db = ref.read(appDatabaseProvider);

      Map<String, dynamic>? bundle;
      if (_athlete.passwordHash.isNotEmpty && _athlete.email.isNotEmpty) {
        final res = await client.rpc(
          'athlete_login_with_password',
          params: {
            'p_identifier': _athlete.email,
            'p_password_hash': _athlete.passwordHash,
          },
        );
        if (res is Map<String, dynamic>) bundle = res;
      } else if (_athlete.accessCode.isNotEmpty) {
        final res = await client.rpc(
          'athlete_login_by_code',
          params: {'p_access_code': _athlete.accessCode},
        );
        if (res is Map<String, dynamic> && res['error'] == null) {
          bundle = res;
        }
      }

      if (bundle == null || !mounted) return;

      final progsList = bundle['programs'] as List<dynamic>? ?? [];
      for (final pRow in progsList) {
        if (pRow is! Map<String, dynamic>) continue;
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
    } catch (_) {}
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() => _remainingRestSeconds = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingRestSeconds <= 1) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        if (mounted) setState(() => _remainingRestSeconds = 0);
      } else {
        if (_remainingRestSeconds <= 4) {
          HapticFeedback.selectionClick();
        }
        setState(() => _remainingRestSeconds--);
      }
    });
  }

  Widget _buildNeonImagePlaceholder(Color primary) {
    return Container(
      color: const Color(0xFF0D110F),
      alignment: Alignment.center,
      child: Icon(LucideIcons.dumbbell,
          size: 24, color: primary.withOpacity(0.65)),
    );
  }

  void _showCinematicExerciseStageModal(
    BuildContext context,
    WorkoutItemEntity ex,
    bool isFa,
    double? previousPr,
  ) {
    final cleanFa = SeedCatalogData.extractCleanPersianTitle(
            ex.exerciseNameFa, ex.exerciseNameEn)
        .toCleanPersian();
    final primary = Theme.of(context).colorScheme.primary;
    final restSec = ex.sets.isNotEmpty ? ex.sets.first.restSeconds : 60;
    final weightCtrl = _getOrInitWeightController(ex.id, previousPr);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          maxChildSize: 0.94,
          minChildSize: 0.60,
          expand: false,
          builder: (_, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(22),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141816),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Row(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: CachedNetworkImage(
                                  cacheManager:
                                      SmartExerciseCacheManager.instance,
                                  imageUrl: ex.imageStartUrl,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) =>
                                      _buildNeonImagePlaceholder(primary),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isFa ? 'شروع حرکت' : 'START POSE',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, color: Colors.white10),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: CachedNetworkImage(
                                  cacheManager:
                                      SmartExerciseCacheManager.instance,
                                  imageUrl: ex.imageEndUrl.isNotEmpty
                                      ? ex.imageEndUrl
                                      : ex.imageStartUrl,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) =>
                                      _buildNeonImagePlaceholder(primary),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isFa ? 'فرم انقباض' : 'FINISH POSE',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFa ? cleanFa : ex.exerciseNameEn,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              ex.exerciseNameEn,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final w =
                            weightCtrl.text.toSafeDouble() ?? previousPr ?? 60;
                        MaxGym3DBarbellPlateModal.show(
                          ctx,
                          weightKg: w,
                          isFa: isFa,
                        );
                      },
                      icon: Icon(LucideIcons.disc, size: 15, color: primary),
                      label: Text(
                        isFa ? 'چیدمان هالتر 3D' : '3D Plates',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if (previousPr != null && previousPr > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFFF8A00).withOpacity(0.45)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.flame,
                            size: 18, color: Color(0xFFFF8A00)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isFa
                                ? 'رکورد قبلی تو در این حرکت: ${previousPr % 1 == 0 ? previousPr.toInt() : previousPr} کیلوگرم — امروز وقت شکستنشه! 🔥'
                                : 'Your Previous PR: ${previousPr}kg — Time to break it! 🔥',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF8A00),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (ex.coachNote.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      '📌 نکته فنی مربی: ${ex.coachNote.toCleanPersian()}',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  isFa
                      ? 'پروتکل ستها (برای شروع تایمر استراحت کرایو روی هر ست بزنید):'
                      : 'Sets Protocol (Tap any set to start Cryo Rest Timer):',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70),
                ),
                const SizedBox(height: 10),
                ...ex.sets.map((s) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151917),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: ListTile(
                      onTap: () {
                        _startRestTimer(s.restSeconds);
                        Navigator.pop(ctx);
                      },
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: primary.withOpacity(0.18),
                        child: Text(
                          '${s.setNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        isFa ? 'تکرار هدف: ${s.reps}' : 'Target Reps: ${s.reps}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      subtitle: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'Tempo: ${s.tempo}  •  Rest: ${s.restSeconds}s${s.isDropSet ? "  •  DROP SET" : ""}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white54),
                        ),
                      ),
                      trailing: Icon(LucideIcons.playCircle, color: primary),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _loggedWeights[ex.id] = v.toEnglishDigits(),
                  decoration: InputDecoration(
                    labelText: isFa
                        ? 'ثبت رکورد وزنه زدهشده (kg)'
                        : 'Log Weight Lifted (kg)',
                    prefixIcon: const Icon(LucideIcons.trophy),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _completedExerciseIds.add(ex.id);
                    });
                    _startRestTimer(restSec);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(LucideIcons.checkCircle2),
                  label: Text(isFa
                      ? 'تکمیل حرکت و شروع ریکاوری کرایو ❄️'
                      : 'Mark Done & Start Cryo Rest ❄️'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitDailyWorkoutLog(FullProgramEntity program) async {
    final db = ref.read(appDatabaseProvider);
    final isFa = AppStrings.of(context).isFa;
    HapticFeedback.heavyImpact();

    final safeIdx = _selectedDayIdx.clamp(0, program.days.length - 1);
    final activeDay = program.days[safeIdx];

    // ذخیره وزنه هم با کلید id حرکت و هم با کلید exerciseId کاتالوگ تا در جلسات بعدی (Ghost PR) همیشه شناخته شود
    final Map<String, String> filteredWeightsForToday = {};
    for (final ex in activeDay.exercises) {
      final val = _loggedWeights[ex.id]?.trim() ?? '';
      if (val.isNotEmpty) {
        filteredWeightsForToday[ex.id] = val;
        if (ex.exerciseId.isNotEmpty) {
          filteredWeightsForToday[ex.exerciseId] = val;
        }
      }
    }

    final log = AthleteWorkoutLogEntity(
      id: const Uuid().v4(),
      athleteId: _athlete.id,
      programId: program.id,
      dayNumber: safeIdx + 1,
      exerciseWeightsKg: filteredWeightsForToday,
      waterGlasses: _waterGlassesToday,
      sessionRpe: 8,
      athleteFeedback: 'Completed via Athlete Portal',
      loggedAt: DateTime.now(),
    );

    db.upsertWorkoutLog(log);

    final updatedAth = db.getAthleteById(_athlete.id);
    if (updatedAth != null) {
      setState(() => _athlete = updatedAth);
    }

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
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
        db.markRecordSynced('athlete_workout_logs', log.id);
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFa
              ? '🏆 پیروزی امروز ثبت شد! رکوردها و گزارش تمرین به صورت زنده برای مربی ارسال گردید.'
              : '🏆 Victory Logged! Today\'s workout & PRs sent live to your coach.'),
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
    final previousPrMap = _buildPreviousPrMap(db);

    final bio = ScientificBioCalculator.analyze(
      gender: _athlete.gender,
      age: _athlete.age,
      heightCm: _athlete.heightCm,
      weightKg: _athlete.weightKg,
      fitnessGoal: _athlete.fitnessGoal,
      waistCm: measurements.isNotEmpty ? measurements.last.waistCm : null,
    );

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 4),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF181D1A),
                  border: Border.all(color: primary, width: 1.8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _athlete.firstName.isNotEmpty
                      ? _athlete.firstName.characters.first.toUpperCase()
                      : 'M',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _athlete.fullName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('👋', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '🔥 ${bio.targetCalories} Kcal  •  🥩 ${bio.proteinGrams}g P  •  ⚡ ${_athlete.streakDays}d Streak',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          MaxGymNotificationBellButton(isFa: isFa),
          if (_selectedTabIndex == 0 && activeProgram != null)
            IconButton(
              tooltip: isFa
                  ? 'حالت تمرکز باشگاه (Gym Focus Mode)'
                  : 'Gym Focus Mode',
              icon: Icon(
                _isGymFocusMode ? LucideIcons.minimize2 : LucideIcons.zap,
                color: _isGymFocusMode ? const Color(0xFFFF8A00) : primary,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _isGymFocusMode = !_isGymFocusMode);
              },
            ),
          if (activeProgram != null)
            IconButton(
              tooltip: isFa ? 'دانلود مجله PDF برنامه من' : 'Download PDF',
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
            icon: const Icon(LucideIcons.logOut, color: Colors.white54),
            onPressed: () => ref.read(securityGateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              // جزیره پویای تایمر استراحت کرایو (Cryo Dynamic Rest Island) در بالای تمام تبها
              MaxGymDynamicRestIsland(
                remainingSeconds: _remainingRestSeconds,
                isFa: isFa,
                onAdd15Seconds: () {
                  setState(() => _remainingRestSeconds += 15);
                },
                onSkipRest: () {
                  _restTimer?.cancel();
                  setState(() => _remainingRestSeconds = 0);
                },
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                    _buildInteractiveWorkoutTab(
                        activeProgram, bio, previousPrMap, isFa, theme),
                    _buildInteractiveNutritionAndWaterTab(
                        activeProgram, bio, isFa, theme),
                    MaxGymTelegramChatView(
                      athlete: _athlete,
                      currentSenderRole: 'athlete',
                    ),
                    _buildAthleteProfileAndAchievementsTab(
                        activeProgram, measurements, bio, isFa, theme),
                    MaxGymClubArenaScreen(
                      isCoachMode: false,
                      currentAthlete: _athlete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // داک ناوبری شیشهای معلق (Floating Spatial Glass Dock) در منطقه طلایی شست
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C100E).withOpacity(0.88),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: NavigationBar(
                  height: 68,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _selectedTabIndex,
                  onDestinationSelected: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTabIndex = i);
                  },
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
                    NavigationDestination(
                      icon: const Icon(LucideIcons.userCheck),
                      label: isFa ? 'پروفایل من' : 'Profile',
                    ),
                    NavigationDestination(
                      icon: const Icon(LucideIcons.trophy),
                      label: isFa ? 'کلاب و رقابت' : 'Arena',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: MaxBotFloatingOrb(
          isCoachMode: false,
          currentAthlete: _athlete,
        ),
      ),
    );
  }

  Widget _buildInteractiveWorkoutTab(
    FullProgramEntity? program,
    BioAnalysisResult bio,
    Map<String, double> previousPrMap,
    bool isFa,
    ThemeData theme,
  ) {
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
                      ? 'میدان نبرد آماده است! منتظر ارسال برنامه جدید از سمت مربی باش ⚡\n(به محض ثبت برنامه توسط مربی، به صورت زنده اینجا ظاهر میشود)'
                      : 'The Arena is ready! Waiting for your coach to assign a plan ⚡',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.6),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _refreshPortalBundleViaRpc,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: Text(
                      isFa ? 'بررسی دریافت برنامه جدید' : 'Refresh Program'),
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

    // پیادهسازی اثر پیشرفت اعطاشده (Endowed Progress Effect) از کتاب Universal Principles of Design:
    // حضور ورزشکار در باشگاه به خودی خود 10% پیشرفت اولیه محسوب میشود و ادامه مسیر تا 100% را تسریع میکند!
    final rawProgress = totalMoves > 0 ? doneMoves / totalMoves : 0.0;
    final endowedProgress = totalMoves == 0
        ? 0.0
        : (doneMoves == totalMoves ? 1.0 : (0.10 + (rawProgress * 0.90)));
    final totalSets =
        activeDay.exercises.fold<int>(0, (sum, ex) => sum + ex.sets.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
      children: [
        if (!_isGymFocusMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  primary,
                  const Color(0xFF388E3C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.trophy, color: primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.title.toCleanPersian(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFa
                            ? 'اعتبار دوره: ${program.durationWeeks} هفته  •  ${program.remainingDays} روز باقیمانده'
                            : '${program.durationWeeks} Weeks Challenge  •  ${program.remainingDays}d Left',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${(endowedProgress * 100).round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: program.days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final d = program.days[i];
              final selected = i == safeIdx;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDayIdx = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 66,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? primary : const Color(0xFF141715),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected
                          ? primary
                          : Colors.white.withOpacity(0.07),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFa
                            ? d.dayNameFa.toCleanPersian()
                            : d.dayNameEn.substring(0, 3),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w600,
                          color: selected ? Colors.black : Colors.white60,
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Colors.black.withOpacity(0.16)
                              : Colors.white.withOpacity(0.05),
                        ),
                        child: Text(
                          '0${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: selected ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        if (activeDay.isRestDay)
          MaxGymGlassCard(
            accentColor: const Color(0xFF00F0FF),
            padding: const EdgeInsets.all(38),
            child: Column(
              children: [
                const Icon(LucideIcons.moon,
                    size: 52, color: Color(0xFF00F0FF)),
                const SizedBox(height: 14),
                Text(
                  isFa
                      ? 'امروز روز استراحت، ریکاوری کرایو و سنتز پروتئین عضلات شماست! 💤❄️'
                      : 'Active Cryo Recovery & Muscle Synthesis Day! 💤❄️',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          )
        else ...[
          if (!_isGymFocusMode) ...[
            MaxGymGlassCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFa
                            ? 'گزارش پیشرفت جلسه (۱۰٪ شارژ اولیه حضور ⚡)'
                            : 'Session Track Record (+10% Check-in Boost ⚡)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          activeDay.targetMuscles.join(' • ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  MaxGymDashedArcGauge(
                    progress: endowedProgress,
                    centerValue: '${(endowedProgress * 100).round()}%',
                    subtitle: isFa
                        ? '$doneMoves از $totalMoves حرکت تکمیل شده'
                        : '$doneMoves of $totalMoves Moves Completed',
                    activeColor: primary,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1F1D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isFa ? 'مجموع ستها' : 'Total Sets',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white60),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '$totalSets Sets',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1F1D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isFa ? 'استمرار تمرین' : 'Streak',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white60),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '${_athlete.streakDays} Days 🔥',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // لیست کارتهای حرکات روز (با رعایت اثر Von Restorff: درخشش نئونی روی حرکت فعال فعلی)
          ...List.generate(activeDay.exercises.length, (idx) {
            final ex = activeDay.exercises[idx];
            final isDone = _completedExerciseIds.contains(ex.id);
            final firstUnfinishedIdx = activeDay.exercises
                .indexWhere((e) => !_completedExerciseIds.contains(e.id));
            final isCurrentActiveSpotlight = idx == firstUnfinishedIdx;

            final restSec =
                ex.sets.isNotEmpty ? ex.sets.first.restSeconds : 60;
            final repsSample =
                ex.sets.isNotEmpty ? ex.sets.first.reps : '10-12';
            final ghostPr =
                previousPrMap[ex.exerciseId] ?? previousPrMap[ex.id];
            final weightCtrl = _getOrInitWeightController(ex.id, ghostPr);

            final cleanPersianTitle = SeedCatalogData.extractCleanPersianTitle(
                    ex.exerciseNameFa, ex.exerciseNameEn)
                .toCleanPersian();

            return MaxGymGlassCard(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              isHighlighted: isCurrentActiveSpotlight,
              accentColor:
                  isDone ? AppColors.success : (isCurrentActiveSpotlight ? primary : null),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showCinematicExerciseStageModal(
                        context, ex, isFa, ghostPr),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 82,
                                height: 82,
                                color: const Color(0xFF0C0F0D),
                                child: ex.imageStartUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        cacheManager:
                                            SmartExerciseCacheManager.instance,
                                        imageUrl: ex.imageStartUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            _buildNeonImagePlaceholder(primary),
                                        errorWidget: (_, __, ___) =>
                                            _buildNeonImagePlaceholder(primary),
                                      )
                                    : _buildNeonImagePlaceholder(primary),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '0${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (ex.supersetGroupId != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      '🔗 SUPERSET (${ex.supersetGroupId})',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ),
                              Text(
                                isFa ? cleanPersianTitle : ex.exerciseNameEn,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: _isGymFocusMode ? 17 : 15,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isFa && ex.exerciseNameEn.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    ex.exerciseNameEn,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  'Sets: ${ex.sets.length}   •   Reps: $repsSample   •   Rest: ${restSec}s',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: isDone,
                            activeColor: primary,
                            checkColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            onChanged: (v) {
                              HapticFeedback.mediumImpact();
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
                  ),

                  // نمایش رکورد جلسه قبل (Ghost PR Tracker)
                  if (ghostPr != null && ghostPr > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8A00).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isFa
                            ? '🔥 رکورد قبلی تو: ${ghostPr % 1 == 0 ? ghostPr.toInt() : ghostPr} کیلوگرم — امروز وقت شکستنشه!'
                            : '🔥 Previous PR: ${ghostPr}kg — Beat it today!',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF8A00),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  // ردیف ثبت وزنه بدون نیاز به کیبورد (-2.5kg / +2.5kg) + هالتر سهبعدی + تایمر استراحت
                  Row(
                    children: [
                      IconButton(
                        tooltip: '-2.5 kg',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.06),
                        ),
                        onPressed: () =>
                            _stepExerciseWeight(ex.id, -2.5, ghostPr),
                        icon: const Icon(LucideIcons.minus, size: 15),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            key: ValueKey('weight_input_${ex.id}'),
                            controller: weightCtrl,
                            onChanged: (val) {
                              _loggedWeights[ex.id] = val.toEnglishDigits();
                            },
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              hintText: isFa
                                  ? 'وزنه (مثلاً 85 kg)'
                                  : 'Weight (kg)',
                              prefixIcon:
                                  const Icon(LucideIcons.trophy, size: 15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: '+2.5 kg',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: primary.withOpacity(0.16),
                          foregroundColor: primary,
                        ),
                        onPressed: () =>
                            _stepExerciseWeight(ex.id, 2.5, ghostPr),
                        icon: const Icon(LucideIcons.plus, size: 15),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: isFa
                            ? 'نمایشگر سهبعدی صفحههای هالتر'
                            : '3D Barbell Plate Calculator',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.06),
                        ),
                        onPressed: () {
                          final w =
                              weightCtrl.text.toSafeDouble() ?? ghostPr ?? 60.0;
                          MaxGym3DBarbellPlateModal.show(
                            context,
                            weightKg: w,
                            isFa: isFa,
                          );
                        },
                        icon: Icon(LucideIcons.disc, size: 16, color: primary),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _startRestTimer(restSec),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(LucideIcons.timer,
                            size: 14, color: Color(0xFF00F0FF)),
                        label: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${restSec}s',
                            style: const TextStyle(color: Color(0xFF00F0FF)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _submitDailyWorkoutLog(program),
              icon: const Icon(LucideIcons.award),
              label: Text(isFa
                  ? 'ثبت پیروزی امروز و ارسال رکوردها برای مربی 🏆'
                  : 'Log Today\'s Victory & Send PRs to Coach 🏆'),
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(
          isFa ? 'نیاز تغذیهای روزانه شما' : 'Your Daily Nutrition',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        MaxGymNeonMacroRings(
          targetCalories: bio.targetCalories,
          proteinGrams: bio.proteinGrams,
          carbsGrams: bio.carbsGrams,
          fatGrams: bio.fatGrams,
          isFa: isFa,
        ),
        const SizedBox(height: 16),
        MaxGymGlassCard(
          accentColor: const Color(0xFF00F0FF),
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
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _waterGlassesToday++);
                    },
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
                  color: const Color(0xFF00F0FF),
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

  Widget _buildAthleteProfileAndAchievementsTab(
      FullProgramEntity? program,
      List<MeasurementLogEntity> measurements,
      BioAnalysisResult bio,
      bool isFa,
      ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final db = ref.read(appDatabaseProvider);
    final workoutLogs = db.getWorkoutLogsForAthlete(_athlete.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // کارت عضویت هولوگرافیک ۳ بعدی باشگاه (3D Touch Holographic VIP Card)
        MaxGym3DTiltCard(
          glowColor: primary,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A221E), Color(0xFF0E1310)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: primary.withOpacity(0.45), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: primary.withOpacity(0.20),
                      child: Text(
                        _athlete.firstName.isNotEmpty
                            ? _athlete.firstName.characters.first.toUpperCase()
                            : 'M',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _athlete.fullName,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              _athlete.email.isNotEmpty
                                  ? _athlete.email
                                  : _athlete.phone,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white60),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFa ? 'VIP MEMBER 👑' : 'VIP PASS 👑',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28, color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _profileStatCol(
                        isFa ? 'وزن فعلی' : 'Weight', '${_athlete.weightKg} kg'),
                    _profileStatCol(isFa ? 'قد' : 'Height',
                        '${_athlete.heightCm.toInt()} cm'),
                    _profileStatCol(
                        isFa ? 'شاخص BMI' : 'BMI', bio.bmi.toString()),
                    _profileStatCol(isFa ? 'استمرار' : 'Streak',
                        '${_athlete.streakDays} 🔥'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        MaxGymGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFa
                            ? 'دستاوردها و رکوردهای شما 🔥'
                            : 'Achievements & Best Results 🔥',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${bio.targetCalories} kcal',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.award, color: primary, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.cyanAccent.withOpacity(0.15),
                  child: const Icon(LucideIcons.dumbbell,
                      color: Colors.cyanAccent, size: 18),
                ),
                title: Text(
                  isFa
                      ? '${workoutLogs.length} جلسه تمرینی تکمیل و ثبتشده'
                      : '${workoutLogs.length} Completed Workout Sessions',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                subtitle: Text(
                  isFa
                      ? 'رکورد استمرار فعلی: ${_athlete.streakDays} روز متوالی'
                      : 'Active consistency streak: ${_athlete.streakDays} days',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        MaxGymGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isFa
                    ? 'تنظیمات امنیتی و بروزرسانی پرونده'
                    : 'Account Security & Check-In',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => MaxGymProfileEditorModal.showForAthlete(
                  context,
                  athlete: _athlete,
                  onUpdated: (updated) => setState(() => _athlete = updated),
                ),
                icon: const Icon(LucideIcons.userCog, size: 16),
                label: Text(isFa
                    ? 'ویرایش پروفایل، عکس آواتار و تغییر رمز عبور امن'
                    : 'Edit Profile, Avatar & Security'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showUpdateWeightAndPasswordDialog(isFa),
                icon: const Icon(LucideIcons.scale, size: 16),
                label: Text(isFa
                    ? 'ثبت سریع وزن جدید در نمودار'
                    : 'Quick Weight Check-in'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileStatCol(String label, String val) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            val,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  void _showUpdateWeightAndPasswordDialog(bool isFa) {
    final weightCtrl =
        TextEditingController(text: _athlete.weightKg.toStringAsFixed(1));
    final waistCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFa
            ? 'بروزرسانی وزن و رمز عبور شخصی'
            : 'Update Weight & Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: weightCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isFa ? 'وزن فعلی (kg)' : 'Current Weight (kg)',
                  prefixIcon: const Icon(LucideIcons.scale),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: waistCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'دور کمر فعلی - cm (اختیاری)'
                      : 'Waist - cm (optional)',
                  prefixIcon: const Icon(LucideIcons.ruler),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'رمز عبور جدید (در صورت تمایل به تغییر)'
                      : 'New Password (optional)',
                  prefixIcon: const Icon(LucideIcons.keyRound),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFa ? 'انصراف' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(appDatabaseProvider);
              final newW =
                  weightCtrl.text.toSafeDouble() ?? _athlete.weightKg;
              final newWaist = waistCtrl.text.toSafeDouble();
              final newP = newPassCtrl.text.trim();
              final newHash = newP.length >= 6
                  ? AthleteEntity.hashPassword(newP)
                  : _athlete.passwordHash;

              final now = DateTime.now();
              final updated = _athlete.copyWith(
                weightKg: newW,
                passwordHash: newHash,
                isCodeBurned: true,
                updatedAt: now,
              );
              db.upsertAthlete(updated);

              final checkInLog = MeasurementLogEntity(
                id: const Uuid().v4(),
                athleteId: updated.id,
                recordedAt: now,
                weightKg: newW,
                waistCm: newWaist,
                updatedAt: now,
              );
              db.insertMeasurementLog(checkInLog);

              setState(() => _athlete = updated);

              try {
                final client = SupabaseConfig.clientOrNull;
                if (client != null) {
                  await client.rpc(
                    'athlete_submit_weight_checkin',
                    params: {
                      'p_id': checkInLog.id,
                      'p_athlete_id': updated.id,
                      'p_access_code': updated.accessCode,
                      'p_weight_kg': newW,
                      'p_waist_cm': newWaist,
                    },
                  );
                  db.markRecordSynced('measurement_logs', checkInLog.id);

                  if (newP.length >= 6) {
                    await client.rpc(
                      'athlete_activate_and_burn_code',
                      params: {
                        'p_athlete_id': updated.id,
                        'p_access_code': updated.accessCode,
                        'p_first_name': updated.firstName,
                        'p_last_name': updated.lastName,
                        'p_phone': updated.phone,
                        'p_email': updated.email,
                        'p_password_hash': updated.passwordHash,
                        'p_age': updated.age,
                        'p_height_cm': updated.heightCm,
                        'p_weight_kg': updated.weightKg,
                      },
                    );
                  }
                }
              } catch (_) {}

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFa
                        ? '✅ وزن جدید در نمودار پیشرفت ثبت شد و پروفایل بروزرسانی گردید!'
                        : '✅ Weight check-in & profile updated!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text(isFa ? 'ذخیره تغییرات' : 'Save'),
          ),
        ],
      ),
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
  late TextEditingController _passwordCtrl;
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
    _passwordCtrl = TextEditingController();
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
    _passwordCtrl.dispose();
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
    final email = _emailCtrl.text.trim().toLowerCase();
    final rawPass = _passwordCtrl.text.trim();
    final age = _ageCtrl.text.toSafeInt() ?? 25;
    final height = _heightCtrl.text.toSafeDouble() ?? 175;
    final weight = _weightCtrl.text.toSafeDouble() ?? 75;

    if (first.isEmpty ||
        last.isEmpty ||
        phone.length < 8 ||
        !email.contains('@') ||
        rawPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFa
              ? 'لطفاً تمام فیلدها (نام، موبایل، ایمیل معتبر و رمز عبور حداقل ۶ کاراکتری) را کامل وارد کنید.'
              : 'Please complete all required fields including a 6+ char password.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final hashedPassword = AthleteEntity.hashPassword(rawPass);

    final updated = AthleteEntity(
      id: widget.athlete.id,
      firstName: first,
      lastName: last,
      phone: phone,
      email: email,
      accessCode: widget.athlete.accessCode,
      passwordHash: hashedPassword,
      isCodeBurned: true,
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
        await client.rpc('athlete_activate_and_burn_code', params: {
          'p_athlete_id': updated.id,
          'p_access_code': updated.accessCode,
          'p_first_name': updated.firstName,
          'p_last_name': updated.lastName,
          'p_phone': updated.phone,
          'p_email': updated.email,
          'p_password_hash': updated.passwordHash,
          'p_age': updated.age,
          'p_height_cm': updated.heightCm,
          'p_weight_kg': updated.weightKg,
        });
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
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(securityGateProvider.notifier).signOut(),
            icon: const Icon(LucideIcons.logOut,
                size: 16, color: AppColors.danger),
            label: Text(
              isFa ? 'خروج / بازگشت' : 'Sign Out',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
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
                          ? 'ورزشکار عزیز، کد دعوت یکبارمصرف شما تایید شد! لطفاً مشخصات و رمز عبور شخصی خود را تعیین کنید (کد دعوت پس از این مرحله باطل شده و در دفعات بعد با ایمیل و رمز عبور خود وارد خواهید شد):'
                          : 'Your one-time invite code is verified! Set your email and personal password for future logins:',
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
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: isFa ? 'شماره تماس *' : 'Phone Number *',
                          prefixIcon: const Icon(LucideIcons.phone),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: isFa ? 'آدرس ایمیل *' : 'Email Address *',
                          prefixIcon: const Icon(LucideIcons.mail),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isFa
                              ? 'تعیین رمز عبور شخصی (حداقل ۶ کاراکتر) *'
                              : 'Set Personal Password (min 6 chars) *',
                          prefixIcon: const Icon(LucideIcons.lock),
                        ),
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
                          ? 'ثبت دائمی، ابطال کد دعوت و ورود به پنل'
                          : 'Activate Account & Enter Portal'),
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
  Timer? _rpcChatPollTimer;

  @override
  void initState() {
    super.initState();
    _messages = ref
        .read(appDatabaseProvider)
        .getChatMessagesForAthlete(widget.athlete.id);
    _subscribeToRealtimeAndRpcChat();
  }

  @override
  void dispose() {
    _realtimeChatSub?.cancel();
    _rpcChatPollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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

  Future<void> _fetchChatViaRpc() async {
    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null || !mounted) return;
      final db = ref.read(appDatabaseProvider);

      final res = await client.rpc(
        'athlete_fetch_chat',
        params: {
          'p_athlete_id': widget.athlete.id,
          'p_access_code': widget.athlete.accessCode,
        },
      );

      if (res is List && mounted) {
        final prevLen = _messages.length;
        for (final r in res) {
          if (r is! Map) continue;
          db.insertChatMessage(ChatMessageEntity(
            id: r['id'] as String,
            athleteId: r['athlete_id'] as String,
            senderRole: r['sender_role'] as String,
            messageText: r['message_text'] as String,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            syncStatus: 'synced',
          ));
        }
        final updatedList = db.getChatMessagesForAthlete(widget.athlete.id);
        setState(() => _messages = updatedList);
        if (updatedList.length > prevLen) {
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  void _subscribeToRealtimeAndRpcChat() {
    _fetchChatViaRpc();
    _rpcChatPollTimer?.cancel();
    _rpcChatPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchChatViaRpc();
    });

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
        _scrollToBottom();
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
    _scrollToBottom();

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        if (widget.currentSenderRole == 'athlete') {
          final ok = await client.rpc(
            'athlete_send_chat',
            params: {
              'p_id': msg.id,
              'p_athlete_id': widget.athlete.id,
              'p_access_code': widget.athlete.accessCode,
              'p_message_text': msg.messageText,
            },
          );
          if (ok == true) {
            db.markRecordSynced('chat_messages', msg.id);
          }
        } else {
          final coachUid = client.auth.currentUser?.id;
          final payload = msg.toSupabaseJson();
          if (coachUid != null) {
            payload['coach_id'] = coachUid;
          }
          await client.from('chat_messages').upsert(payload);
          db.markRecordSynced('chat_messages', msg.id);
        }
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
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.refreshCw, size: 15),
                    onPressed: _fetchChatViaRpc,
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
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 94),
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