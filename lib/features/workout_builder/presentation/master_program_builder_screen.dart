import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/cache/smart_cache_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_models.dart';
import '../../../data/local/seed_catalog_data.dart';
import '../../athletes/domain/scientific_bio_calculator.dart';

class MasterProgramBuilderScreen extends ConsumerStatefulWidget {
  final AthleteEntity athlete;
  final FullProgramEntity? initialProgramOrTemplate;
  final void Function(AthleteEntity athlete, FullProgramEntity savedProgram)?
      onSavedAndExportPdf;

  const MasterProgramBuilderScreen({
    super.key,
    required this.athlete,
    this.initialProgramOrTemplate,
    this.onSavedAndExportPdf,
  });

  @override
  ConsumerState<MasterProgramBuilderScreen> createState() =>
      _MasterProgramBuilderScreenState();
}

class _MasterProgramBuilderScreenState
    extends ConsumerState<MasterProgramBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _uuid = Uuid();

  late TextEditingController _programTitleCtrl;
  int _durationWeeks = 4;
  int _selectedDayIndex = 0; // 0 = شنبه (Day 1) تا 6 = جمعه (Day 7)

  late List<WorkoutDayPlan> _days;
  late List<DietMealSlot> _dietMeals;
  double _waterLiters = 3.5;
  final List<String> _dietGuidelines = [
    'مصرف نمک صورتی و آب کافی قبل و حین تمرین الزامی است.',
    'وزنکشی مواد غذایی به صورت پخته و بدون روغن اضافه محاسبه شود.',
  ];
  late List<SupplementPrescriptionItem> _supplements;

  // وضعیت مالی و پکیجها
  bool _incTuition = false;
  bool _incWorkout = true;
  bool _incDiet = true;
  bool _incSupplement = false;
  late TextEditingController _totalFeeCtrl;
  late TextEditingController _paidAmountCtrl;
  bool _saveAsTemplate = false;

  static const List<Map<String, String>> _muscleGroups = [
    {'id': 'chest', 'fa': 'سینه', 'en': 'Chest'},
    {'id': 'back', 'fa': 'زیربغل و پشت', 'en': 'Back & Lats'},
    {'id': 'shoulders', 'fa': 'سرشانه', 'en': 'Shoulders'},
    {'id': 'biceps', 'fa': 'جلوبازو', 'en': 'Biceps'},
    {'id': 'triceps', 'fa': 'پشتبازو', 'en': 'Triceps'},
    {'id': 'legs', 'fa': 'پا و سرینی', 'en': 'Legs & Glutes'},
    {'id': 'abs', 'fa': 'شکم و پهلو', 'en': 'Abs & Core'},
    {'id': 'calves', 'fa': 'ساق پا', 'en': 'Calves'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final branding = ref.read(brandingProvider);
    final initProg = widget.initialProgramOrTemplate;

    _programTitleCtrl = TextEditingController(
      text: initProg?.title ?? 'برنامه اختصاصی دوره جدید - ${widget.athlete.fullName}',
    );
    _durationWeeks = initProg?.durationWeeks ?? 4;

    if (initProg != null) {
      _days = List<WorkoutDayPlan>.from(initProg.days);
      _dietMeals = List<DietMealSlot>.from(initProg.dietMeals);
      _waterLiters = initProg.waterLiters;
      _supplements = List<SupplementPrescriptionItem>.from(initProg.supplements);
      _totalFeeCtrl =
          TextEditingController(text: initProg.totalFee.toStringAsFixed(0));
      _paidAmountCtrl =
          TextEditingController(text: initProg.paidAmount.toStringAsFixed(0));
    } else {
      _days = _buildDefault7Days();
      _dietMeals = _buildDefaultMealSlots();
      _supplements = [];
      final defaultTotal =
          branding.defaultWorkoutFee + branding.defaultDietFee;
      _totalFeeCtrl =
          TextEditingController(text: defaultTotal.toStringAsFixed(0));
      _paidAmountCtrl =
          TextEditingController(text: defaultTotal.toStringAsFixed(0));
    }
  }

  List<WorkoutDayPlan> _buildDefault7Days() {
    const namesFa = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سهشنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه'
    ];
    const namesEn = [
      'Saturday',
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday'
    ];
    return List.generate(7, (i) {
      return WorkoutDayPlan(
        dayNumber: i + 1,
        dayNameFa: namesFa[i],
        dayNameEn: namesEn[i],
        isRestDay: i == 2 || i == 6, // دوشنبه و جمعه پیشفرض استراحت
        targetMuscles: const [],
        exercises: const [],
      );
    });
  }

  List<DietMealSlot> _buildDefaultMealSlots() {
    return const [
      DietMealSlot(
          slotId: 'breakfast',
          titleFa: 'وعده اول: صبحانه',
          titleEn: 'Meal 1: Breakfast',
          timeRange: '08:00'),
      DietMealSlot(
          slotId: 'snack1',
          titleFa: 'وعده دوم: میانوعده صبح',
          titleEn: 'Meal 2: Morning Snack',
          timeRange: '11:00'),
      DietMealSlot(
          slotId: 'lunch',
          titleFa: 'وعده سوم: ناهار',
          titleEn: 'Meal 3: Lunch',
          timeRange: '14:00'),
      DietMealSlot(
          slotId: 'pre_workout',
          titleFa: 'وعده چهارم: قبل از تمرین (انرژی)',
          titleEn: 'Meal 4: Pre-Workout',
          timeRange: '17:00'),
      DietMealSlot(
          slotId: 'post_workout',
          titleFa: 'وعده پنجم: بعد از تمرین (ریکاوری)',
          titleEn: 'Meal 5: Post-Workout',
          timeRange: '19:30'),
      DietMealSlot(
          slotId: 'dinner',
          titleFa: 'وعده ششم: شام',
          titleEn: 'Meal 6: Dinner',
          timeRange: '21:30'),
    ];
  }

  void _recalcPackageFee() {
    final b = ref.read(brandingProvider);
    double sum = 0;
    if (_incTuition) sum += b.defaultTuitionFee;
    if (_incWorkout) sum += b.defaultWorkoutFee;
    if (_incDiet) sum += b.defaultDietFee;
    if (_incSupplement) sum += b.defaultSupplementFee;
    setState(() {
      _totalFeeCtrl.text = sum.toStringAsFixed(0);
      _paidAmountCtrl.text = sum.toStringAsFixed(0);
    });
  }

  /// بارگذاری سریع یک قالب آماده (Template) در ۱ ثانیه
  void _loadFromTemplateDialog(bool isFa) {
    final db = ref.read(appDatabaseProvider);
    final templates = db.getSavedTemplates();

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (templates.isEmpty) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Text(isFa
                  ? 'هنوز قالبی ذخیره نکردهاید. در تب آخر گزینه «ذخیره به عنوان قالب» را بزنید.'
                  : 'No saved templates yet.'),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: templates.length,
          itemBuilder: (ctx, i) {
            final t = templates[i];
            return Card(
              child: ListTile(
                leading: const Icon(LucideIcons.copy),
                title: Text(t.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${t.durationWeeks} Weeks'),
                onTap: () {
                  setState(() {
                    _days = List<WorkoutDayPlan>.from(t.days);
                    _dietMeals = List<DietMealSlot>.from(t.dietMeals);
                    _supplements =
                        List<SupplementPrescriptionItem>.from(t.supplements);
                    _waterLiters = t.waterLiters;
                  });
                  Navigator.pop(ctx);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _saveProgram({bool exportPdfAfter = false}) {
    final db = ref.read(appDatabaseProvider);
    final total = double.tryParse(_totalFeeCtrl.text) ?? 0;
    final paid = double.tryParse(_paidAmountCtrl.text) ?? 0;
    final status =
        paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');

    final now = DateTime.now();
    final program = FullProgramEntity(
      id: _uuid.v4(),
      athleteId: widget.athlete.id,
      title: _programTitleCtrl.text.trim().isEmpty
          ? 'برنامه دوره جدید'
          : _programTitleCtrl.text.trim(),
      startDate: now,
      durationWeeks: _durationWeeks,
      days: _days,
      dietMeals: _dietMeals,
      waterLiters: _waterLiters,
      dietGuidelines: _dietGuidelines,
      supplements: _supplements,
      totalFee: total,
      paidAmount: paid,
      paymentStatus: status,
      isTemplate: false,
      updatedAt: now,
    );

    db.upsertProgram(program);

    // ذخیره نسخه قالب آماده با UUID معتبر برای سازگاری ۱۰۰٪ با PostgreSQL در Supabase
    if (_saveAsTemplate) {
      final templateCopy = FullProgramEntity(
        id: _uuid.v4(),
        athleteId: widget.athlete.id, // UUID معتبر
        title: 'قالب آماده: ${_programTitleCtrl.text.trim()}',
        startDate: now,
        durationWeeks: _durationWeeks,
        days: _days,
        dietMeals: _dietMeals,
        waterLiters: _waterLiters,
        dietGuidelines: _dietGuidelines,
        supplements: _supplements,
        totalFee: total,
        paidAmount: total,
        paymentStatus: 'paid',
        isTemplate: true,
        updatedAt: now,
      );
      db.upsertProgram(templateCopy);
    }

    Navigator.pop(context, program);
    if (exportPdfAfter && widget.onSavedAndExportPdf != null) {
      widget.onSavedAndExportPdf!(widget.athlete, program);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFa
              ? 'طراحی برنامه: ${widget.athlete.fullName}'
              : 'Plan Builder: ${widget.athlete.fullName}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _loadFromTemplateDialog(isFa),
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: Text(isFa ? 'لود قالب آماده' : 'Load Template'),
          ),
          IconButton(
            tooltip: isFa ? 'ذخیره و خروجی PDF' : 'Save & Export PDF',
            icon: Icon(LucideIcons.fileCheck2,
                color: theme.colorScheme.primary),
            onPressed: () => _saveProgram(exportPdfAfter: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(LucideIcons.dumbbell, size: 18),
              text: isFa ? '۱. تمرین (هفتگی/سوپرست)' : '1. Workout Split',
            ),
            Tab(
              icon: const Icon(LucideIcons.utensils, size: 18),
              text: isFa ? '۲. رژیم غذایی' : '2. Diet Plan',
            ),
            Tab(
              icon: const Icon(LucideIcons.pill, size: 18),
              text: isFa ? '۳. مکملها' : '3. Supplements',
            ),
            Tab(
              icon: const Icon(LucideIcons.wallet, size: 18),
              text: isFa ? '۴. پکیج مالی و ثبت' : '4. Billing & Save',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWorkoutTab(isFa, theme),
          _buildDietTab(isFa, theme),
          _buildSupplementTab(isFa, theme),
          _buildBillingAndSaveTab(isFa, theme),
        ],
      ),
    );
  }

  // ===========================================================================
  // تب ۱: طراحی ماکرو و میکرو تمرین (Weekly Split + Superset + Tempo + Injury Alert)
  // ===========================================================================
  Widget _buildWorkoutTab(bool isFa, ThemeData theme) {
    final activeDay = _days[_selectedDayIndex];

    return Column(
      children: [
        // نوار افقی انتخاب روزهای هفته (Macro Split)
        Container(
          height: 82,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: theme.colorScheme.surface,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final d = _days[i];
              final isSelected = i == _selectedDayIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 98,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isFa ? d.dayNameFa : d.dayNameEn,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.isRestDay
                            ? (isFa ? 'استراحت 💤' : 'Rest Day 💤')
                            : (isFa
                                ? '${d.exercises.length} حرکت'
                                : '${d.exercises.length} Moves'),
                        style: TextStyle(
                          fontSize: 11,
                          color: d.isRestDay
                              ? Colors.grey
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // محتوای روز انتخابشده
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // سوییچ روز استراحت / روز تمرین
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFa
                        ? 'وضعیت ${activeDay.dayNameFa}:'
                        : '${activeDay.dayNameEn} Status:',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Switch.adaptive(
                    value: !activeDay.isRestDay,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (isTraining) {
                      setState(() {
                        _days[_selectedDayIndex] = WorkoutDayPlan(
                          dayNumber: activeDay.dayNumber,
                          dayNameFa: activeDay.dayNameFa,
                          dayNameEn: activeDay.dayNameEn,
                          isRestDay: !isTraining,
                          targetMuscles: activeDay.targetMuscles,
                          exercises: activeDay.exercises,
                        );
                      });
                    },
                  ),
                ],
              ),

              if (activeDay.isRestDay)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      isFa
                          ? 'این روز به عنوان روز استراحت و ریکاوری تنظیم شده است. 💤'
                          : 'Marked as Rest & Recovery Day. 💤',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else ...[
                // تگهای انتخاب عضلات هدف آن روز
                const SizedBox(height: 8),
                Text(
                  isFa
                      ? 'عضلات هدف این جلسه (Macro Split):'
                      : 'Target Muscle Groups:',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _muscleGroups.map((m) {
                    final id = m['id']!;
                    final selected = activeDay.targetMuscles.contains(id);
                    return FilterChip(
                      label: Text(isFa ? m['fa']! : m['en']!),
                      selected: selected,
                      selectedColor:
                          theme.colorScheme.primary.withOpacity(0.25),
                      onSelected: (val) {
                        final updatedMuscles =
                            List<String>.from(activeDay.targetMuscles);
                        if (val) {
                          updatedMuscles.add(id);
                        } else {
                          updatedMuscles.remove(id);
                        }
                        setState(() {
                          _days[_selectedDayIndex] = WorkoutDayPlan(
                            dayNumber: activeDay.dayNumber,
                            dayNameFa: activeDay.dayNameFa,
                            dayNameEn: activeDay.dayNameEn,
                            isRestDay: false,
                            targetMuscles: updatedMuscles,
                            exercises: activeDay.exercises,
                          );
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // دکمه افزودن حرکت از بانک دوزبانه حرکات
                ElevatedButton.icon(
                  onPressed: () =>
                      _showExercisePickerSheet(activeDay, isFa, theme),
                  icon: const Icon(LucideIcons.plus),
                  label: Text(isFa
                      ? 'افزودن حرکت به ${activeDay.dayNameFa}'
                      : 'Add Exercise to ${activeDay.dayNameEn}'),
                ),
                const SizedBox(height: 16),

                // لیست حرکات انتخابشده در این روز + پشتیبانی از سوپرست و تنظیم ست/تمپو
                ...List.generate(activeDay.exercises.length, (exIdx) {
                  final item = activeDay.exercises[exIdx];
                  final nextItem = exIdx + 1 < activeDay.exercises.length
                      ? activeDay.exercises[exIdx + 1]
                      : null;
                  final isLinkedWithNext = item.supersetGroupId != null &&
                      nextItem?.supersetGroupId == item.supersetGroupId;

                  return Column(
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: item.supersetGroupId != null
                                ? AppColors.warning
                                : Colors.white12,
                            width: item.supersetGroupId != null ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // تصویر کوچک حرکت با کش ۵۰ مگابایتی
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      cacheManager:
                                          SmartExerciseCacheManager.instance,
                                      imageUrl: item.imageStartUrl,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 52,
                                        height: 52,
                                        color: Colors.black26,
                                        child: const Icon(LucideIcons.dumbbell,
                                            size: 20),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 52,
                                        height: 52,
                                        color: Colors.black26,
                                        child: const Icon(LucideIcons.imageOff,
                                            size: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (item.supersetGroupId != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.warning
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isFa
                                                  ? '🔗 سوپرست / ترکیبی (${item.setType.name.toUpperCase()})'
                                                  : '🔗 ${item.setType.name.toUpperCase()}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          isFa
                                              ? item.exerciseNameFa
                                              : item.exerciseNameEn,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                        Text(
                                          isFa
                                              ? item.exerciseNameEn
                                              : item.exerciseNameFa,
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.sliders,
                                        size: 18),
                                    onPressed: () =>
                                        _showFastSetTempoConfigurator(
                                            activeDay, exIdx, isFa, theme),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2,
                                        size: 18, color: AppColors.danger),
                                    onPressed: () {
                                      final list = List<WorkoutItemEntity>.from(
                                          activeDay.exercises)
                                        ..removeAt(exIdx);
                                      _updateActiveDayExercises(list);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // خلاصه ستها، تکرار و تمپو
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: item.sets.map((s) {
                                  return Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      'S${s.setNumber}: ${s.reps} | T:${s.tempo} | Rest:${s.restSeconds}s'
                                      '${s.isDropSet ? " (DROP)" : ""}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // دکمه زنجیر (🔗) بین دو حرکت متوالی برای ساخت آنی سوپرست یا تریست!
                      if (nextItem != null)
                        Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                _toggleSupersetLink(activeDay, exIdx),
                            icon: Icon(
                              isLinkedWithNext
                                  ? LucideIcons.unlink
                                  : LucideIcons.link,
                              size: 15,
                              color: isLinkedWithNext
                                  ? AppColors.warning
                                  : Colors.grey,
                            ),
                            label: Text(
                              isLinkedWithNext
                                  ? (isFa
                                      ? 'لغو سوپرست با حرکت بعدی'
                                      : 'Unlink Superset')
                                  : (isFa
                                      ? 'سوپرست با حرکت بعدی 🔗'
                                      : 'Link as Superset 🔗'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isLinkedWithNext
                                    ? AppColors.warning
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                    ],
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _updateActiveDayExercises(List<WorkoutItemEntity> updated) {
    final activeDay = _days[_selectedDayIndex];
    setState(() {
      _days[_selectedDayIndex] = WorkoutDayPlan(
        dayNumber: activeDay.dayNumber,
        dayNameFa: activeDay.dayNameFa,
        dayNameEn: activeDay.dayNameEn,
        isRestDay: activeDay.isRestDay,
        targetMuscles: activeDay.targetMuscles,
        exercises: updated,
      );
    });
  }

  /// اتصال یا جداسازی دو حرکت متوالی به عنوان سوپرست / تریست
  void _toggleSupersetLink(WorkoutDayPlan activeDay, int index) {
    final list = List<WorkoutItemEntity>.from(activeDay.exercises);
    final current = list[index];
    final next = list[index + 1];

    final isAlreadyLinked = current.supersetGroupId != null &&
        current.supersetGroupId == next.supersetGroupId;

    if (isAlreadyLinked) {
      list[index] = WorkoutItemEntity(
        id: current.id,
        exerciseId: current.exerciseId,
        exerciseNameFa: current.exerciseNameFa,
        exerciseNameEn: current.exerciseNameEn,
        targetMuscle: current.targetMuscle,
        imageStartUrl: current.imageStartUrl,
        imageEndUrl: current.imageEndUrl,
        orderIndex: current.orderIndex,
        setType: SetType.normal,
        supersetGroupId: null,
        sets: current.sets,
      );
      list[index + 1] = WorkoutItemEntity(
        id: next.id,
        exerciseId: next.exerciseId,
        exerciseNameFa: next.exerciseNameFa,
        exerciseNameEn: next.exerciseNameEn,
        targetMuscle: next.targetMuscle,
        imageStartUrl: next.imageStartUrl,
        imageEndUrl: next.imageEndUrl,
        orderIndex: next.orderIndex,
        setType: SetType.normal,
        supersetGroupId: null,
        sets: next.sets,
      );
    } else {
      final groupId = current.supersetGroupId ?? 'SS_${_uuid.v4().substring(0, 5)}';
      list[index] = WorkoutItemEntity(
        id: current.id,
        exerciseId: current.exerciseId,
        exerciseNameFa: current.exerciseNameFa,
        exerciseNameEn: current.exerciseNameEn,
        targetMuscle: current.targetMuscle,
        imageStartUrl: current.imageStartUrl,
        imageEndUrl: current.imageEndUrl,
        orderIndex: current.orderIndex,
        setType: SetType.superset,
        supersetGroupId: groupId,
        sets: current.sets,
      );
      list[index + 1] = WorkoutItemEntity(
        id: next.id,
        exerciseId: next.exerciseId,
        exerciseNameFa: next.exerciseNameFa,
        exerciseNameEn: next.exerciseNameEn,
        targetMuscle: next.targetMuscle,
        imageStartUrl: next.imageStartUrl,
        imageEndUrl: next.imageEndUrl,
        orderIndex: next.orderIndex,
        setType: SetType.superset,
        supersetGroupId: groupId,
        sets: next.sets,
      );
    }

    _updateActiveDayExercises(list);
  }

  /// پنجره انتخاب حرکت ورزشی با هشدار هوشمند آسیبدیدگی (Injury Warning Engine)
  void _showExercisePickerSheet(
      WorkoutDayPlan activeDay, bool isFa, ThemeData theme) {
    final db = ref.read(appDatabaseProvider);
    String? filterMuscle =
        activeDay.targetMuscles.isNotEmpty ? activeDay.targetMuscles.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final catalog =
                db.getExercisesCatalog(muscleFilter: filterMuscle);

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(isFa ? 'همه عضلات' : 'All'),
                            selected: filterMuscle == null,
                            onSelected: (_) =>
                                setSheetState(() => filterMuscle = null),
                          ),
                          const SizedBox(width: 6),
                          ..._muscleGroups.map((m) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(isFa ? m['fa']! : m['en']!),
                                selected: filterMuscle == m['id'],
                                onSelected: (_) => setSheetState(
                                    () => filterMuscle = m['id']),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: catalog.length,
                        itemBuilder: (ctx, idx) {
                          final ex = catalog[idx];
                          // بررسی تداخل حرکت با آسیبدیدگیهای ثبتشده برای شاگرد
                          final conflictingInjuries = ex.contraindicatedInjuries
                              .where((inj) =>
                                  widget.athlete.injuryTags.contains(inj))
                              .toList();
                          final hasInjuryConflict =
                              conflictingInjuries.isNotEmpty;

                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                cacheManager:
                                    SmartExerciseCacheManager.instance,
                                imageUrl: ex.imageStartUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const Icon(LucideIcons.dumbbell),
                              ),
                            ),
                            title: Text(
                              isFa ? ex.nameFa : ex.nameEn,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isFa ? ex.nameEn : ex.nameFa,
                                    style: const TextStyle(fontSize: 12)),
                                if (hasInjuryConflict)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.warning.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isFa
                                          ? '⚠️ هشدار آسیبدیدگی شاگرد: ${conflictingInjuries.join(", ")}'
                                          : '⚠️ Injury Warning: ${conflictingInjuries.join(", ")}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(LucideIcons.plusCircle,
                                  color: theme.colorScheme.primary),
                              onPressed: () {
                                final newItem = WorkoutItemEntity(
                                  id: _uuid.v4(),
                                  exerciseId: ex.id,
                                  exerciseNameFa: ex.nameFa,
                                  exerciseNameEn: ex.nameEn,
                                  targetMuscle: ex.targetMuscle,
                                  imageStartUrl: ex.imageStartUrl,
                                  imageEndUrl: ex.imageEndUrl,
                                  orderIndex: activeDay.exercises.length + 1,
                                  sets: const [
                                    SingleSetConfig(
                                        setNumber: 1, reps: '10-12'),
                                    SingleSetConfig(
                                        setNumber: 2, reps: '10-12'),
                                    SingleSetConfig(
                                        setNumber: 3, reps: '8-10'),
                                  ],
                                );
                                final updated = List<WorkoutItemEntity>.from(
                                    activeDay.exercises)
                                  ..add(newItem);
                                _updateActiveDayExercises(updated);
                                Navigator.pop(ctx);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// انتخابگر فوقسریع بدون نیاز به کیبورد برای ستها، تکرار، تمپو، دراپست و استراحت
  void _showFastSetTempoConfigurator(
      WorkoutDayPlan activeDay, int exIdx, bool isFa, ThemeData theme) {
    final item = activeDay.exercises[exIdx];
    int setCount = item.sets.length;
    String selectedReps = item.sets.first.reps;
    String selectedTempo = item.sets.first.tempo;
    int selectedRest = item.sets.first.restSeconds;
    bool lastSetDrop = item.sets.last.isDropSet;

    const repPresets = [
      '6-8',
      '8-10',
      '10-12',
      '12-15',
      '15-20',
      'Failure (ناتوانی)',
      '45s'
    ];
    const tempoPresets = [
      '2-0-1-0 (نرمال)',
      '3-1-1-0 (کنترلی)',
      '4-0-1-0 (منفی تمرکزی)',
      '1-0-X-0 (انفجاری)',
      '2-2-1-1 (ایزومتریک)'
    ];
    const restPresets = [45, 60, 90, 120, 180];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFa ? item.exerciseNameFa : item.exerciseNameEn,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // ۱. تعداد ستها
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isFa ? 'تعداد ستها:' : 'Number of Sets:',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 8,
                        children: [2, 3, 4, 5, 6].map((cnt) {
                          return ChoiceChip(
                            label: Text('$cnt'),
                            selected: setCount == cnt,
                            onSelected: (_) =>
                                setModalState(() => setCount = cnt),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ۲. محدوده تکرار (بدون تایپ)
                  Text(isFa ? 'محدوده تکرار (Reps):' : 'Target Reps:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: repPresets.map((r) {
                      return ChoiceChip(
                        label: Text(r),
                        selected: selectedReps == r,
                        onSelected: (_) =>
                            setModalState(() => selectedReps = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // ۳. ریتم و تمپو اجرای حرکت (Tempo)
                  Text(isFa ? 'تمپو و سیستم اجرا (Tempo):' : 'Tempo / Speed:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: tempoPresets.map((t) {
                      final code = t.split(' ').first;
                      return ChoiceChip(
                        label: Text(t),
                        selected: selectedTempo == code,
                        onSelected: (_) =>
                            setModalState(() => selectedTempo = code),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // ۴. زمان استراحت بین ستها و دراپست
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isFa ? 'استراحت (ثانیه):' : 'Rest (sec):',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 6,
                        children: restPresets.map((sec) {
                          return ChoiceChip(
                            label: Text('${sec}s'),
                            selected: selectedRest == sec,
                            onSelected: (_) =>
                                setModalState(() => selectedRest = sec),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isFa
                        ? 'ست آخر دراپست (Drop Set) باشد؟'
                        : 'Make Final Set a Drop-Set?'),
                    value: lastSetDrop,
                    onChanged: (v) => setModalState(() => lastSetDrop = v),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final newSets = List.generate(setCount, (i) {
                          return SingleSetConfig(
                            setNumber: i + 1,
                            reps: selectedReps,
                            tempo: selectedTempo,
                            restSeconds: selectedRest,
                            isDropSet: (i == setCount - 1) && lastSetDrop,
                          );
                        });
                        final list = List<WorkoutItemEntity>.from(
                            activeDay.exercises);
                        list[exIdx] = WorkoutItemEntity(
                          id: item.id,
                          exerciseId: item.exerciseId,
                          exerciseNameFa: item.exerciseNameFa,
                          exerciseNameEn: item.exerciseNameEn,
                          targetMuscle: item.targetMuscle,
                          imageStartUrl: item.imageStartUrl,
                          imageEndUrl: item.imageEndUrl,
                          orderIndex: item.orderIndex,
                          setType: lastSetDrop ? SetType.dropSet : item.setType,
                          supersetGroupId: item.supersetGroupId,
                          sets: newSets,
                        );
                        _updateActiveDayExercises(list);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(LucideIcons.check),
                      label: Text(isFa ? 'اعمال سریع' : 'Apply Config'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // تب ۲: طراحی فوقسریع رژیم غذایی (با منطق جایگزین "یا" / OR Logic)
  // ===========================================================================
  Widget _buildDietTab(bool isFa, ThemeData theme) {
    final bio = ScientificBioCalculator.analyze(
      gender: widget.athlete.gender,
      age: widget.athlete.age,
      heightCm: widget.athlete.heightCm,
      weightKg: widget.athlete.weightKg,
      fitnessGoal: widget.athlete.fitnessGoal,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // هدر هوشمند نمایش ماکروهای هدف شاگرد
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('🔥 ${bio.targetCalories} kcal',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('🥩 P: ${bio.proteinGrams}g'),
              Text('🍚 C: ${bio.carbsGrams}g'),
              Text('🥑 F: ${bio.fatGrams}g'),
              Text('🌿 Fib: ${bio.fiberGrams}g'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // اسلایدر تنظیم آب مصرفی روزانه
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFa
                      ? '💧 آب مصرفی روزانه: ${_waterLiters.toStringAsFixed(1)} لیتر (پیشنهاد علمی: ${bio.waterLiters} لیتر)'
                      : '💧 Daily Hydration: ${_waterLiters.toStringAsFixed(1)} L',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _waterLiters,
                  min: 1.5,
                  max: 6.0,
                  divisions: 18,
                  label: '${_waterLiters.toStringAsFixed(1)} L',
                  onChanged: (v) => setState(() => _waterLiters = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // لیست ۶ وعده غذایی
        ...List.generate(_dietMeals.length, (slotIdx) {
          final slot = _dietMeals[slotIdx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFa ? slot.titleFa : slot.titleEn,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _showQuickFoodPicker(slotIdx, isFa),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(isFa ? 'افزودن غذا' : 'Add Food'),
                      ),
                    ],
                  ),
                  if (slot.items.isEmpty)
                    Text(
                      isFa ? 'خالی (روی افزودن غذا بزنید)' : 'No items added',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else
                    ...List.generate(slot.items.length, (itemIdx) {
                      final f = slot.items[itemIdx];
                      final alts =
                          isFa ? f.alternativesFa : f.alternativesEn;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isFa
                              ? '• ${f.foodNameFa} (${f.amountFa})'
                              : '• ${f.foodNameEn} (${f.amountEn})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: alts.isNotEmpty
                            ? Text(
                                isFa
                                    ? '   [یا جایگزین]: ${alts.join(" / یا ")}'
                                    : '   [OR]: ${alts.join(" / OR ")}',
                                style: const TextStyle(
                                    color: Colors.orangeAccent, fontSize: 12),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _showAddAlternativeOption(
                                  slotIdx, itemIdx, isFa),
                              child: Text(isFa ? '+ جایگزین (یا)' : '+ OR'),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                final updatedItems =
                                    List<MealFoodRow>.from(slot.items)
                                      ..removeAt(itemIdx);
                                setState(() {
                                  _dietMeals[slotIdx] = DietMealSlot(
                                    slotId: slot.slotId,
                                    titleFa: slot.titleFa,
                                    titleEn: slot.titleEn,
                                    timeRange: slot.timeRange,
                                    items: updatedItems,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showQuickFoodPicker(int slotIdx, bool isFa) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: SeedCatalogData.quickFoodCatalog.length,
          itemBuilder: (ctx, i) {
            final food = SeedCatalogData.quickFoodCatalog[i];
            return ListTile(
              leading: const Icon(LucideIcons.utensilsCrossed),
              title: Text(isFa ? food['nameFa']! : food['nameEn']!),
              subtitle: Text(isFa ? food['unitFa']! : food['unitEn']!),
              onTap: () {
                final slot = _dietMeals[slotIdx];
                final newRow = MealFoodRow(
                  foodNameFa: food['nameFa']!,
                  foodNameEn: food['nameEn']!,
                  amountFa: food['unitFa']!,
                  amountEn: food['unitEn']!,
                );
                setState(() {
                  _dietMeals[slotIdx] = DietMealSlot(
                    slotId: slot.slotId,
                    titleFa: slot.titleFa,
                    titleEn: slot.titleEn,
                    timeRange: slot.timeRange,
                    items: [...slot.items, newRow],
                  );
                });
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  void _showAddAlternativeOption(int slotIdx, int itemIdx, bool isFa) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: SeedCatalogData.quickFoodCatalog.length,
          itemBuilder: (ctx, i) {
            final alt = SeedCatalogData.quickFoodCatalog[i];
            return ListTile(
              title: Text(isFa
                  ? '[یا] ${alt['nameFa']} (${alt['unitFa']})'
                  : '[OR] ${alt['nameEn']} (${alt['unitEn']})'),
              onTap: () {
                final slot = _dietMeals[slotIdx];
                final item = slot.items[itemIdx];
                final updatedItem = MealFoodRow(
                  foodNameFa: item.foodNameFa,
                  foodNameEn: item.foodNameEn,
                  amountFa: item.amountFa,
                  amountEn: item.amountEn,
                  alternativesFa: [
                    ...item.alternativesFa,
                    '${alt['nameFa']} (${alt['unitFa']})'
                  ],
                  alternativesEn: [
                    ...item.alternativesEn,
                    '${alt['nameEn']} (${alt['unitEn']})'
                  ],
                );
                final updatedList = List<MealFoodRow>.from(slot.items);
                updatedList[itemIdx] = updatedItem;
                setState(() {
                  _dietMeals[slotIdx] = DietMealSlot(
                    slotId: slot.slotId,
                    titleFa: slot.titleFa,
                    titleEn: slot.titleEn,
                    timeRange: slot.timeRange,
                    items: updatedList,
                  );
                });
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // تب ۳: ماتریس پروتکل مکملها (Supplement Protocol Matrix)
  // ===========================================================================
  Widget _buildSupplementTab(bool isFa, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          isFa
              ? 'انتخاب سریع از بانک مکملهای استاندارد:'
              : 'Quick-Add from Supplement Catalog:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SeedCatalogData.supplementCatalog.map((sup) {
            return ActionChip(
              avatar: const Icon(LucideIcons.plus, size: 16),
              label: Text(isFa ? sup['nameFa']! : sup['nameEn']!),
              onPressed: () {
                setState(() {
                  _supplements.add(
                    SupplementPrescriptionItem(
                      supplementId: sup['id']!,
                      nameFa: sup['nameFa']!,
                      nameEn: sup['nameEn']!,
                      dosageFa: sup['defaultDosageFa']!,
                      dosageEn: sup['defaultDosageEn']!,
                      timingFa: sup['defaultTimingFa']!,
                      timingEn: sup['defaultTimingEn']!,
                      onlyTrainingDays: sup['id'] == 'caffeine_pre' ||
                          sup['id'] == 'bcaa_eaa',
                    ),
                  );
                });
              },
            );
          }).toList(),
        ),
        const Divider(height: 32),
        if (_supplements.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(isFa
                  ? 'مکملی برای این دوره انتخاب نشده است.'
                  : 'No supplements prescribed.'),
            ),
          )
        else
          ...List.generate(_supplements.length, (i) {
            final s = _supplements[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(LucideIcons.pill),
                title: Text(
                  isFa ? s.nameFa : s.nameEn,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isFa
                      ? 'دوز: ${s.dosageFa} | زمان: ${s.timingFa}\n${s.onlyTrainingDays ? "⚡ فقط روزهای تمرین" : "📅 مصرف روزانه"}'
                      : 'Dose: ${s.dosageEn} | Timing: ${s.timingEn}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(LucideIcons.trash2, color: AppColors.danger),
                  onPressed: () => setState(() => _supplements.removeAt(i)),
                ),
              ),
            );
          }),
      ],
    );
  }

  // ===========================================================================
  // تب ۴: مدیریت مالی، پکیجها، تاریخ انقضا و ذخیره قالب آماده
  // ===========================================================================
  Widget _buildBillingAndSaveTab(bool isFa, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _programTitleCtrl,
          decoration: InputDecoration(
            labelText: isFa ? 'عنوان برنامه / دوره' : 'Program Title',
            prefixIcon: const Icon(LucideIcons.fileText),
          ),
        ),
        const SizedBox(height: 16),

        // مدت زمان اعتبار برنامه (برای هشدار انقضای داشبورد)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isFa ? 'مدت اعتبار دوره (هفته):' : 'Program Duration (Weeks):',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: [4, 6, 8, 12].map((w) {
                return ChoiceChip(
                  label: Text(isFa ? '$w هفته' : '${w}W'),
                  selected: _durationWeeks == w,
                  onSelected: (_) => setState(() => _durationWeeks = w),
                );
              }).toList(),
            ),
          ],
        ),
        const Divider(height: 32),

        // انتخابگر پکیج خدمات مالی
        Text(
          isFa
              ? 'پکیج خدمات ارائه شده به شاگرد (محاسبه خودکار شهریه):'
              : 'Included Coaching Services & Tuition:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _incTuition,
          title: Text(isFa ? 'شهریه باشگاه' : 'Gym Membership Tuition'),
          onChanged: (v) {
            _incTuition = v ?? false;
            _recalcPackageFee();
          },
        ),
        CheckboxListTile(
          value: _incWorkout,
          title: Text(isFa ? 'برنامه تمرینی تخصصی' : 'Workout Plan'),
          onChanged: (v) {
            _incWorkout = v ?? false;
            _recalcPackageFee();
          },
        ),
        CheckboxListTile(
          value: _incDiet,
          title: Text(isFa ? 'برنامه رژیم غذایی و ماکرو' : 'Nutrition Plan'),
          onChanged: (v) {
            _incDiet = v ?? false;
            _recalcPackageFee();
          },
        ),
        CheckboxListTile(
          value: _incSupplement,
          title: Text(isFa ? 'پروتکل مکملهای ورزشی' : 'Supplement Stack'),
          onChanged: (v) {
            _incSupplement = v ?? false;
            _recalcPackageFee();
          },
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _totalFeeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      isFa ? 'مبلغ کل فاکتور (تومان)' : 'Total Fee Amount',
                  prefixIcon: const Icon(LucideIcons.receipt),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _paidAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isFa ? 'مبلغ پرداختشده' : 'Amount Paid',
                  prefixIcon: const Icon(LucideIcons.checkCircle),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        SwitchListTile(
          value: _saveAsTemplate,
          title: Text(
            isFa
                ? 'ذخیره یک نسخه در «قالبهای آماده» برای شاگردان بعدی'
                : 'Also save as Reusable Smart Template',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onChanged: (v) => setState(() => _saveAsTemplate = v),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _saveProgram(exportPdfAfter: false),
                icon: const Icon(LucideIcons.save),
                label: Text(isFa ? 'ذخیره برنامه' : 'Save Only'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _saveProgram(exportPdfAfter: true),
                icon: const Icon(LucideIcons.fileOutput),
                label: Text(isFa
                    ? 'ذخیره + تولید PDF اختصاصی'
                    : 'Save & Generate PDF'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
