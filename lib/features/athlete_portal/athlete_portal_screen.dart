import 'dart:async';
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
import '../../data/local/app_database.dart';
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

  // وضعیت تمرین روز، وزنه‌های زده‌شده، لیوان‌های آب و تایمر استراحت کم‌مصرف
  final Map<String, String> _loggedWeights = {};
  final Set<String> _completedExerciseIds = {};
  int _waterGlassesToday = 0;

  Timer? _restTimer;
  int _remainingRestSeconds = 0;

  @override
  void initState() {
    super.initState();
    _athlete = widget.initialAthlete;
    // تشخیص خودکار روز هفته برای باز کردن تمرین امروز
    final weekday = DateTime.now().weekday; // Mon=1 .. Sun=7
    // تبدیل به شنبه=0 تا جمعه=6
    _selectedDayIdx = (weekday + 1) % 7;
  }

  @override
  void didUpdateWidget(covariant AthletePortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAthlete != widget.initialAthlete) {
      _athlete = widget.initialAthlete;
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
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
      await SupabaseConfig.clientOrNull?.rpc(
        'athlete_submit_workout_log',
        params: {
          'p_id': log.id,
          'p_athlete_id': _athlete.id,
          'p_access_code': _athlete.accessCode,
          'p_program_id': log.programId,
          'p_day_number': log.dayNumber,
          'p_completed_sets_json': log.exerciseMaxWeights,
          'p_water_glasses': log.waterGlasses,
          'p_session_rpe': log.sessionRpe,
          'p_athlete_feedback': log.athleteFeedback,
        },
      );
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFa
              ? '🏆 آفرین! رکوردها و گزارش تمرین امروزت برای مربی ارسال شد.'
              : '🏆 Awesome! Today\'s workout & PRs sent to your coach.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _showWeightCheckInDialog(bool isFa) async {
    final wCtrl =
        TextEditingController(text: _athlete.weightKg.toStringAsFixed(1));
    final waistCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isFa
            ? '⚖️ ثبت وزن و سایز جدید برای مربی'
            : '⚖️ Weekly Weight Check-In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: isFa ? 'وزن فعلی (kg) *' : 'Current Weight (kg) *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: waistCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      isFa ? 'دور کمر (cm) - اختیاری' : 'Waist (cm) - Optional'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(isFa ? 'انصراف' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newW = wCtrl.text.toSafeDouble() ?? _athlete.weightKg;
              final newWaist = waistCtrl.text.toSafeDouble();
              final logId = const Uuid().v4();
              final now = DateTime.now();

              ref.read(appDatabaseProvider).insertMeasurementLog(
                    MeasurementLogEntity(
                      id: logId,
                      athleteId: _athlete.id,
                      recordedAt: now,
                      weightKg: newW,
                      waistCm: newWaist,
                      updatedAt: now,
                      syncStatus: 'synced',
                    ),
                  );

              try {
                await SupabaseConfig.clientOrNull?.rpc(
                  'athlete_submit_weight_checkin',
                  params: {
                    'p_id': logId,
                    'p_athlete_id': _athlete.id,
                    'p_access_code': _athlete.accessCode,
                    'p_weight_kg': newW,
                    'p_waist_cm': newWaist,
                  },
                );
              } catch (_) {}

              setState(() {
                _athlete = AthleteEntity(
                  id: _athlete.id,
                  firstName: _athlete.firstName,
                  lastName: _athlete.lastName,
                  phone: _athlete.phone,
                  email: _athlete.email,
                  accessCode: _athlete.accessCode,
                  gender: _athlete.gender,
                  age: _athlete.age,
                  heightCm: _athlete.heightCm,
                  weightKg: newW,
                  fitnessGoal: _athlete.fitnessGoal,
                  injuryTags: _athlete.injuryTags,
                  createdAt: _athlete.createdAt,
                  updatedAt: now,
                );
              });
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: Text(isFa ? 'ارسال برای مربی' : 'Submit Check-In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);
    final db = ref.watch(appDatabaseProvider);

    // ۱. گیت اجباری تکمیل اطلاعات پروفایل ورزشکار در صورت ناقص بودن (طبق دستور شما)
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFa
                  ? 'پنل ورزشکار: ${_athlete.fullName}'
                  : 'Athlete: ${_athlete.fullName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '🔥 ${bio.targetCalories} kcal | 🥩 ${bio.proteinGrams}g Protein',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
            ),
          ],
        ),
        actions: [
          // نمایش تایمر معکوس استراحت در هدر در صورت فعال بودن
          if (_remainingRestSeconds > 0)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.warning),
              ),
              alignment: Alignment.center,
              child: Text(
                '⏱ ${_remainingRestSeconds}s',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ),
          IconButton(
            tooltip: isFa
                ? '⚖️ ثبت وزن و سایز جدید برای مربی'
                : '⚖️ Weekly Weight Check-In',
            icon: const Icon(LucideIcons.scale),
            onPressed: () => _showWeightCheckInDialog(isFa),
          ),
          if (activeProgram != null)
            IconButton(
              tooltip: isFa ? 'دانلود PDF برنامه من' : 'Download My PDF Plan',
              icon: const Icon(LucideIcons.fileDown),
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
            tooltip: isFa ? 'خروج از پنل ورزشکار' : 'Sign Out',
            icon: const Icon(LucideIcons.logOut, color: AppColors.danger),
            onPressed: () => ref.read(securityGateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildInteractiveWorkoutTab(activeProgram, isFa, theme),
          _buildInteractiveNutritionAndWaterTab(
              activeProgram, bio, isFa, theme),
          PureTextChatView(
            athlete: _athlete,
            currentSenderRole: 'athlete',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (i) => setState(() => _selectedTabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.dumbbell),
            label: isFa ? 'تمرین امروز و رکورد' : 'Today\'s Workout',
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.apple),
            label: isFa ? 'تغذیه، مکمل و آب' : 'Diet & Water',
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.messageSquare),
            label: isFa ? 'گفتگو با مربی' : 'Coach Chat',
          ),
        ],
      ),
    );
  }

  /// تب ۱: اجرای تعاملی تمرین روزانه، ثبت وزنه، تیک ستها و تایمر استراحت
  Widget _buildInteractiveWorkoutTab(
      FullProgramEntity? program, bool isFa, ThemeData theme) {
    if (program == null || program.days.isEmpty) {
      return Center(
        child: Text(isFa
            ? 'مربی هنوز برنامه‌ای برای شما ثبت نکرده است.'
            : 'No active workout plan assigned yet.'),
      );
    }

    final safeIdx = _selectedDayIdx.clamp(0, program.days.length - 1);
    final activeDay = program.days[safeIdx];
    final totalMoves = activeDay.exercises.length;
    final doneMoves = activeDay.exercises
        .where((e) => _completedExerciseIds.contains(e.id))
        .length;
    final progress = totalMoves > 0 ? doneMoves / totalMoves : 0.0;

    return Column(
      children: [
        // نوار انتخاب روز هفته
        SizedBox(
          height: 68,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: program.days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final d = program.days[i];
              final selected = i == safeIdx;
              return ChoiceChip(
                label: Text(isFa ? d.dayNameFa : d.dayNameEn),
                selected: selected,
                onSelected: (_) => setState(() => _selectedDayIdx = i),
              );
            },
          ),
        ),
        // نوار پیشرفت جلسه امروز
        if (!activeDay.isRestDay && totalMoves > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFa
                          ? 'پیشرفت جلسه امروز: $doneMoves از $totalMoves حرکت'
                          : 'Session Progress: $doneMoves / $totalMoves',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 7,
                ),
              ],
            ),
          ),
        Expanded(
          child: activeDay.isRestDay
              ? Center(
                  child: Text(isFa
                      ? 'امروز روز استراحت و ریکاوری عضلات شماست! 💤💧'
                      : 'Rest & Recovery Day! Stay hydrated 💤💧'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeDay.exercises.length + 1,
                  itemBuilder: (ctx, idx) {
                    if (idx == activeDay.exercises.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 40),
                        child: ElevatedButton.icon(
                          onPressed: () => _submitDailyWorkoutLog(program),
                          icon: const Icon(LucideIcons.trophy),
                          label: Text(isFa
                              ? 'ثبت نهایی تمرین امروز و ارسال رکورد برای مربی'
                              : 'Finish Workout & Send Log to Coach'),
                        ),
                      );
                    }

                    final ex = activeDay.exercises[idx];
                    final isDone = _completedExerciseIds.contains(ex.id);
                    final restSec =
                        ex.sets.isNotEmpty ? ex.sets.first.restSeconds : 60;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDone
                              ? AppColors.success
                              : (ex.supersetGroupId != null
                                  ? AppColors.warning
                                  : Colors.white12),
                          width: isDone || ex.supersetGroupId != null ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    cacheManager:
                                        SmartExerciseCacheManager.instance,
                                    imageUrl: ex.imageStartUrl,
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const Icon(LucideIcons.dumbbell),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (ex.supersetGroupId != null)
                                        Text(
                                          '🔗 SUPERSET (${ex.supersetGroupId})',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      Text(
                                        '${idx + 1}. ${isFa ? ex.exerciseNameFa : ex.exerciseNameEn}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                      if (ex.coachNote.isNotEmpty)
                                        Text(
                                          '📌 ${ex.coachNote}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.primary),
                                        ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: isDone,
                                  activeColor: AppColors.success,
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
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: ex.sets.map((s) {
                                return ActionChip(
                                  avatar: const Icon(LucideIcons.timer,
                                      size: 14),
                                  label: Text(
                                    'S${s.setNumber}: ${s.reps} | T:${s.tempo}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () =>
                                      _startRestTimer(s.restSeconds),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: TextField(
                                      onChanged: (val) {
                                        _loggedWeights[ex.id] =
                                            val.toEnglishDigits();
                                      },
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: isFa
                                            ? 'ثبت وزنه زده‌شده (مثلاً 80 kg)'
                                            : 'Log weight lifted (e.g. 80 kg)',
                                        prefixIcon: const Icon(
                                            LucideIcons.award,
                                            size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _startRestTimer(restSec),
                                  icon:
                                      const Icon(LucideIcons.timer, size: 16),
                                  label: Text('${restSec}s'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// تب ۲: برنامه غذایی، مکملها و کنتور تعاملی لیوانهای آب روزانه
  Widget _buildInteractiveNutritionAndWaterTab(FullProgramEntity? program,
      BioAnalysisResult bio, bool isFa, ThemeData theme) {
    final targetGlasses = ((program?.waterLiters ?? bio.waterLiters) * 4).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // کنتور گیمیفایشده آب مصرفی
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFa
                          ? '💧 آب مصرفی امروز: $_waterGlassesToday از $targetGlasses لیوان'
                          : '💧 Water Intake: $_waterGlassesToday / $targetGlasses Glasses',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _waterGlassesToday++),
                      icon: const Icon(LucideIcons.glassWater, size: 16),
                      label: Text(isFa ? '+۱ لیوان' : '+1 Glass'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: targetGlasses > 0
                      ? (_waterGlassesToday / targetGlasses).clamp(0.0, 1.0)
                      : 0.0,
                  color: Colors.lightBlueAccent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (program != null) ...[
          Text(
            isFa ? '🍽 وعده‌های غذایی و جایگزین‌ها:' : '🍽 Daily Meal Plan:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...program.dietMeals.where((m) => m.items.isNotEmpty).map((meal) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFa ? meal.titleFa : meal.titleEn,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...meal.items.map((item) {
                      final alts =
                          isFa ? item.alternativesFa : item.alternativesEn;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          isFa
                              ? '• ${item.foodNameFa} (${item.amountFa})${alts.isNotEmpty ? "\n   [یا جایگزین: ${alts.join(" / ")}]" : ""}'
                              : '• ${item.foodNameEn} (${item.amountEn})${alts.isNotEmpty ? "\n   [OR: ${alts.join(" / ")}]" : ""}',
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          if (program.supplements.isNotEmpty) ...[
            Text(
              isFa ? '💊 پروتکل مکمل و ویتامین‌ها:' : '💊 Supplement Stack:',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...program.supplements.map((s) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(LucideIcons.pill),
                  title: Text(isFa ? s.nameFa : s.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isFa
                      ? '${s.dosageFa} | ${s.timingFa}'
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

// =============================================================================
// گیت تکمیل اجباری مشخصات ورزشکار در اولین ورود (Mandatory Profile Gate)
// =============================================================================
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
      syncStatus: 'pending_update',
    );

    ref.read(appDatabaseProvider).upsertAthlete(updated);

    // آپدیت امن در سرور Supabase از طریق RPC
    try {
      await SupabaseConfig.clientOrNull?.rpc('athlete_complete_profile', params: {
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
    } catch (_) {}

    widget.onCompleted(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFa
            ? 'تکمیل اجباری پرونده ورزشی شما'
            : 'Complete Your Athlete Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            isFa
                ? 'ورزشکار عزیز، برای محاسبه دقیق شاخص‌های بدنی و ارتباط آنلاین با مربی، لطفاً مشخصات زیر را کامل نمایید:'
                : 'Please complete your profile details to unlock your training portal:',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
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
                      labelText: isFa ? 'نام خانوادگی *' : 'Last Name *'),
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
                  decoration:
                      InputDecoration(labelText: isFa ? 'سن *' : 'Age *'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isFa ? 'قد (cm) *' : 'Height (cm) *'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isFa ? 'وزن (kg) *' : 'Weight (kg) *'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saveCompleteProfile,
            icon: const Icon(LucideIcons.checkCircle2),
            label: Text(isFa
                ? 'تایید مشخصات و ورود به برنامه تمرینی'
                : 'Save & Enter Portal'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ویجت چت متنی خالص دوطرفه (مربی <-> ورزشکار) با مصرف باتری و رم نزدیک به صفر
// =============================================================================
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

class _PureTextChatViewState extends ConsumerState<PureTextChatView>
    with WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  List<ChatMessageEntity> _messages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalAndFetchRemote();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.dispose();
    super.dispose();
  }

  /// قطع فعالیت هنگام رفتن اپ به پس‌زمینه برای صفر کردن مصرف باتری
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLocalAndFetchRemote();
    }
  }

  Future<void> _loadLocalAndFetchRemote() async {
    final db = ref.read(appDatabaseProvider);
    if (mounted) {
      setState(() {
        _messages = db.getChatMessagesForAthlete(widget.athlete.id);
      });
    }

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null) return;

      List<Map<String, dynamic>> rawRows = [];

      if (widget.currentSenderRole == 'athlete') {
        final res = await client.rpc(
          'athlete_fetch_chat',
          params: {
            'p_athlete_id': widget.athlete.id,
            'p_access_code': widget.athlete.accessCode,
          },
        ).timeout(const Duration(seconds: 5));
        if (res is List<dynamic>) {
          rawRows = res.whereType<Map<String, dynamic>>().toList();
        }
      } else {
        final rows = await client
            .from('chat_messages')
            .select()
            .eq('athlete_id', widget.athlete.id)
            .order('created_at', ascending: true)
            .limit(100);
        rawRows = List<Map<String, dynamic>>.from(rows);
      }

      for (final r in rawRows) {
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
      }
    } catch (_) {}
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
        if (widget.currentSenderRole == 'athlete') {
          await client.rpc(
            'athlete_send_chat',
            params: {
              'p_id': msg.id,
              'p_athlete_id': widget.athlete.id,
              'p_access_code': widget.athlete.accessCode,
              'p_message_text': msg.messageText,
            },
          ).timeout(const Duration(seconds: 5));
        } else {
          await client.from('chat_messages').upsert(msg.toSupabaseJson());
        }
        db.markRecordSynced('chat_messages', msg.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isFa
                    ? '💬 گفتگوی متنی خالص (${widget.athlete.fullName})'
                    : '💬 Pure Text Direct Chat (${widget.athlete.fullName})',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                onPressed: _loadLocalAndFetchRemote,
              ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    isFa
                        ? 'هنوز پیامی ارسال نشده است. سوال یا گزارش خود را بنویسید.'
                        : 'No messages yet. Start the conversation.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) {
                    final m = _messages[i];
                    final isMe = m.senderRole == widget.currentSenderRole;
                    return Align(
                      alignment: isMe
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 290),
                        decoration: BoxDecoration(
                          color: isMe
                              ? theme.colorScheme.primary.withOpacity(0.22)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMe
                                ? theme.colorScheme.primary.withOpacity(0.5)
                                : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.messageText,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: const Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  maxLength: 500,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: isFa
                        ? 'پیام متنی خود را بنویسید (حداکثر ۵۰۰ کاراکتر)...'
                        : 'Write a text message...',
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
    );
  }
}
