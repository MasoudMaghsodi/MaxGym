import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/cache/smart_cache_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../../core/utils/number_parser.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_models.dart';
import '../../../data/local/seed_catalog_data.dart';
import '../../../data/remote/supabase_sync_service.dart';
import '../../athletes/domain/scientific_bio_calculator.dart';

class MasterProgramBuilderScreen extends ConsumerStatefulWidget {
  final AthleteEntity athlete;
  final FullProgramEntity? initialProgramOrTemplate;
  final bool isEditingExisting; // اگر true باشد همان برنامه قبلی را آپدیت میکند
  final void Function(AthleteEntity athlete, FullProgramEntity savedProgram)?
      onSavedAndExportPdf;

  const MasterProgramBuilderScreen({
    super.key,
    required this.athlete,
    this.initialProgramOrTemplate,
    this.isEditingExisting = false,
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
  int _selectedDayIndex = 0;

  late List<WorkoutDayPlan> _days;
  late List<DietMealSlot> _dietMeals;
  double _waterLiters = 3.5;
  final List<String> _dietGuidelines = [
    'مصرف نمک صورتی و آب کافی قبل و حین تمرین الزامی است.',
    'وزنکشی مواد غذایی به صورت پخته و بدون روغن اضافه محاسبه شود.',
  ];
  late List<SupplementPrescriptionItem> _supplements;

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
      text: initProg?.title ??
          'برنامه اختصاصی دوره جدید - ${widget.athlete.fullName}',
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

    if (widget.initialProgramOrTemplate == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final draft = ref
            .read(appDatabaseProvider)
            .getProgramDraft(widget.athlete.id);
        if (draft != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'یک پیش‌نویس ناتمام برای این شاگرد پیدا شد. بازیابی شود؟'),
              action: SnackBarAction(
                label: 'بازیابی پیش‌نویس',
                onPressed: () {
                  setState(() {
                    _programTitleCtrl.text = draft.title;
                    _days = List<WorkoutDayPlan>.from(draft.days);
                    _dietMeals = List<DietMealSlot>.from(draft.dietMeals);
                    _supplements =
                        List<SupplementPrescriptionItem>.from(draft.supplements);
                  });
                },
              ),
            ),
          );
        }
      });
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
        isRestDay: i == 2 || i == 6,
        targetMuscles: <String>[],
        exercises: <WorkoutItemEntity>[],
      );
    });
  }

  List<DietMealSlot> _buildDefaultMealSlots() {
    return [
      const DietMealSlot(
        slotId: 'breakfast',
        titleFa: 'وعده اول: صبحانه',
        titleEn: 'Meal 1: Breakfast',
        timeRange: '08:00',
      ),
      const DietMealSlot(
        slotId: 'snack1',
        titleFa: 'وعده دوم: میانوعده صبح',
        titleEn: 'Meal 2: Morning Snack',
        timeRange: '11:00',
      ),
      const DietMealSlot(
        slotId: 'lunch',
        titleFa: 'وعده سوم: ناهار',
        titleEn: 'Meal 3: Lunch',
        timeRange: '14:00',
      ),
      const DietMealSlot(
        slotId: 'pre_workout',
        titleFa: 'وعده چهارم: قبل از تمرین (انرژی)',
        titleEn: 'Meal 4: Pre-Workout',
        timeRange: '17:00',
      ),
      const DietMealSlot(
        slotId: 'post_workout',
        titleFa: 'وعده پنجم: بعد از تمرین (ریکاوری)',
        titleEn: 'Meal 5: Post-Workout',
        timeRange: '19:30',
      ),
      const DietMealSlot(
        slotId: 'dinner',
        titleFa: 'وعده ششم: شام',
        titleEn: 'Meal 6: Dinner',
        timeRange: '21:30',
      ),
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
    final total = _totalFeeCtrl.text.toSafeDouble() ?? 0;
    final paid = _paidAmountCtrl.text.toSafeDouble() ?? 0;
    final status =
        paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');

    final now = DateTime.now();
    final isEdit =
        widget.isEditingExisting && widget.initialProgramOrTemplate != null;

    final program = FullProgramEntity(
      id: isEdit ? widget.initialProgramOrTemplate!.id : _uuid.v4(),
      athleteId: widget.athlete.id,
      title: _programTitleCtrl.text.trim().isEmpty
          ? 'برنامه دوره جدید'
          : _programTitleCtrl.text.trim(),
      startDate:
          isEdit ? widget.initialProgramOrTemplate!.startDate : now,
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
      syncStatus: isEdit ? 'pending_update' : 'pending_insert',
    );

    db.upsertProgram(program);
    db.clearProgramDraft(widget.athlete.id);

    // Auto-sync immediately to Supabase
    unawaited(ref.read(supabaseSyncServiceProvider).syncAllPendingData());

    if (_saveAsTemplate) {
      final templateCopy = FullProgramEntity(
        id: _uuid.v4(),
        athleteId: widget.athlete.id,
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
          widget.isEditingExisting
              ? (isFa
                  ? 'ویرایش برنامه: ${widget.athlete.fullName}'
                  : 'Edit Plan: ${widget.athlete.fullName}')
              : (isFa
                  ? 'طراحی برنامه: ${widget.athlete.fullName}'
                  : 'Plan Builder: ${widget.athlete.fullName}'),
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _loadFromTemplateDialog(isFa),
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: Text(isFa ? 'لود قالب' : 'Template'),
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
              text: isFa ? '۱. تمرین (Drag & Superset)' : '1. Workout Split',
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
  // تب ۱: تمرین با قابلیت Drag & Drop، سوپرست، تمپو، یادداشت مربی و افزودن حرکت سفارشی
  // ===========================================================================
  Widget _buildWorkoutTab(bool isFa, ThemeData theme) {
    final activeDay = _days[_selectedDayIndex];

    return Column(
      children: [
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
                        : theme.cardColor,
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
                            ? (isFa ? 'استراحت 💤' : 'Rest 💤')
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showExercisePickerSheet(activeDay, isFa, theme),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: Text(isFa
                            ? 'افزودن حرکت به ${activeDay.dayNameFa}'
                            : 'Add Exercise'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: activeDay.exercises.isEmpty
                            ? null
                            : () => _showDuplicateDayDialog(activeDay, isFa),
                        icon: const Icon(LucideIcons.copyPlus, size: 16),
                        label: Text(isFa ? 'کپی روز' : 'Copy Day'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activeDay.exercises.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      isFa
                          ? '💡 نکته: با نگه داشتن دستگیره (☰) میتوانید ترتیب حرکات را جابجا (Drag & Drop) کنید.'
                          : '💡 Tip: Drag handle (☰) to reorder exercises.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),

                // لیست حرکات با قابلیت Drag & Drop Reordering
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeDay.exercises.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final list =
                        List<WorkoutItemEntity>.from(activeDay.exercises);
                    final moved = list.removeAt(oldIndex);
                    list.insert(newIndex, moved);
                    for (int i = 0; i < list.length; i++) {
                      list[i] = list[i].copyWith(orderIndex: i + 1);
                    }
                    _updateActiveDayExercises(list);
                  },
                  itemBuilder: (ctx, exIdx) {
                    final item = activeDay.exercises[exIdx];
                    final nextItem = exIdx + 1 < activeDay.exercises.length
                        ? activeDay.exercises[exIdx + 1]
                        : null;
                    final isLinkedWithNext = item.supersetGroupId != null &&
                        nextItem?.supersetGroupId == item.supersetGroupId;

                    return Column(
                      key: ValueKey(item.id),
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
                                    ReorderableDragStartListener(
                                      index: exIdx,
                                      child: const Padding(
                                        padding: EdgeInsets.only(
                                            left: 6, right: 6),
                                        child: Icon(LucideIcons.gripVertical,
                                            size: 20, color: Colors.grey),
                                      ),
                                    ),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        cacheManager:
                                            SmartExerciseCacheManager.instance,
                                        imageUrl: item.imageStartUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.black26,
                                          child: const Icon(
                                              LucideIcons.dumbbell,
                                              size: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item.supersetGroupId != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '🔗 ${item.setType.name.toUpperCase()}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.warning,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            '${exIdx + 1}. ${isFa ? item.exerciseNameFa : item.exerciseNameEn}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                          if (item.coachNote.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4),
                                              child: Text(
                                                '📌 ${item.coachNote}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme
                                                      .colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: isFa
                                          ? 'تنظیم ست، تمپو و یادداشت'
                                          : 'Configure Sets & Note',
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
                                        final removedItem =
                                            activeDay.exercises[exIdx];
                                        final list =
                                            List<WorkoutItemEntity>.from(
                                                activeDay.exercises)
                                              ..removeAt(exIdx);
                                        _updateActiveDayExercises(list);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(isFa
                                                ? 'حرکت ${removedItem.exerciseNameFa} حذف شد'
                                                : '${removedItem.exerciseNameEn} removed'),
                                            action: SnackBarAction(
                                              label: isFa ? 'بازگردانی' : 'Undo',
                                              onPressed: () {
                                                final restoredList =
                                                    List<WorkoutItemEntity>.from(
                                                        _days[_selectedDayIndex]
                                                            .exercises);
                                                final insertPos = exIdx.clamp(
                                                    0, restoredList.length);
                                                restoredList.insert(
                                                    insertPos, removedItem);
                                                _updateActiveDayExercises(
                                                    restoredList);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: item.sets.map((s) {
                                    return Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        'S${s.setNumber}: ${s.reps} | T:${s.tempo} | Rest:${s.restSeconds}s'
                                        '${s.isDropSet ? " [DROP]" : ""}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                  },
                ),
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
    // ذخیره خودکار پیش‌نویس (Auto-Draft - رفع عیب ۱ گزارش ممیزی)
    ref.read(appDatabaseProvider).saveProgramDraft(
          widget.athlete.id,
          FullProgramEntity(
            id: 'DRAFT_${widget.athlete.id}',
            athleteId: widget.athlete.id,
            title: _programTitleCtrl.text,
            startDate: DateTime.now(),
            durationWeeks: _durationWeeks,
            days: _days,
            dietMeals: _dietMeals,
            waterLiters: _waterLiters,
            dietGuidelines: _dietGuidelines,
            supplements: _supplements,
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// کپی کردن تمام حرکات و سوپرستهای یک روز روی روز دیگر هفته (Duplicate Day)
  void _showDuplicateDayDialog(WorkoutDayPlan sourceDay, bool isFa) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: _days.length,
          itemBuilder: (ctx, targetIdx) {
            if (targetIdx == _selectedDayIndex) return const SizedBox.shrink();
            final targetDay = _days[targetIdx];
            return ListTile(
              leading: const Icon(LucideIcons.copyPlus),
              title: Text(isFa
                  ? 'کپی حرکات ${sourceDay.dayNameFa} روی ${targetDay.dayNameFa}'
                  : 'Copy ${sourceDay.dayNameEn} to ${targetDay.dayNameEn}'),
              onTap: () {
                setState(() {
                  _days[targetIdx] = WorkoutDayPlan(
                    dayNumber: targetDay.dayNumber,
                    dayNameFa: targetDay.dayNameFa,
                    dayNameEn: targetDay.dayNameEn,
                    isRestDay: false,
                    targetMuscles: List<String>.from(sourceDay.targetMuscles),
                    exercises: sourceDay.exercises
                        .map((e) => WorkoutItemEntity(
                              id: _uuid.v4(),
                              exerciseId: e.exerciseId,
                              exerciseNameFa: e.exerciseNameFa,
                              exerciseNameEn: e.exerciseNameEn,
                              targetMuscle: e.targetMuscle,
                              imageStartUrl: e.imageStartUrl,
                              imageEndUrl: e.imageEndUrl,
                              orderIndex: e.orderIndex,
                              setType: e.setType,
                              supersetGroupId: e.supersetGroupId,
                              sets: List<SingleSetConfig>.from(e.sets),
                              coachNote: e.coachNote,
                            ))
                        .toList(),
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

  void _toggleSupersetLink(WorkoutDayPlan activeDay, int index) {
    final list = List<WorkoutItemEntity>.from(activeDay.exercises);
    final current = list[index];
    final next = list[index + 1];

    final isAlreadyLinked = current.supersetGroupId != null &&
        current.supersetGroupId == next.supersetGroupId;

    if (isAlreadyLinked) {
      list[index] =
          current.copyWith(setType: SetType.normal, clearSuperset: true);
      list[index + 1] =
          next.copyWith(setType: SetType.normal, clearSuperset: true);
    } else {
      final groupId =
          current.supersetGroupId ?? 'SS_${_uuid.v4().substring(0, 4)}';
      list[index] = current.copyWith(
          setType: SetType.superset, supersetGroupId: groupId);
      list[index + 1] = next.copyWith(
          setType: SetType.superset, supersetGroupId: groupId);
    }

    _updateActiveDayExercises(list);
  }

  /// پنجره انتخاب حرکت با نوار جستجو + دکمه ساخت حرکت سفارشی مربی
  void _showExercisePickerSheet(
      WorkoutDayPlan activeDay, bool isFa, ThemeData theme) {
    final db = ref.read(appDatabaseProvider);
    String? filterMuscle = activeDay.targetMuscles.isNotEmpty
        ? activeDay.targetMuscles.first
        : null;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final catalog = db.getExercisesCatalog(
              muscleFilter: filterMuscle,
              searchQuery: searchQuery,
            );

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (v) =>
                                  setSheetState(() => searchQuery = v),
                              decoration: InputDecoration(
                                hintText: isFa
                                    ? 'جستجوی نام حرکت (فارسی یا انگلیسی)...'
                                    : 'Search exercise...',
                                prefixIcon:
                                    const Icon(LucideIcons.search, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _showCreateCustomExerciseDialog(
                                  ctx, isFa, filterMuscle ?? 'chest');
                              setSheetState(() {});
                            },
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: Text(
                                isFa ? 'حرکت سفارشی' : 'Custom Move'),
                          ),
                        ],
                      ),
                    ),
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

  /// دیالوگ افزودن حرکت ورزشی سفارشی توسط مربی به بانک دائمی
  Future<void> _showCreateCustomExerciseDialog(
      BuildContext ctx, bool isFa, String initialMuscle) async {
    final nameFaCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    String selectedMuscle = initialMuscle;

    await showDialog(
      context: ctx,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              title: Text(isFa
                  ? 'افزودن حرکت سفارشی به بانک من'
                  : 'Add Custom Exercise'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameFaCtrl,
                    decoration: InputDecoration(
                      labelText: isFa ? 'نام فارسی حرکت *' : 'Persian Name *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameEnCtrl,
                    decoration: InputDecoration(
                      labelText: isFa
                          ? 'نام انگلیسی (برای جستجوی ویدیو و PDF)'
                          : 'English Name *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedMuscle,
                    decoration: InputDecoration(
                        labelText: isFa ? 'عضله هدف' : 'Target Muscle'),
                    items: _muscleGroups.map((m) {
                      return DropdownMenuItem(
                        value: m['id'],
                        child: Text(isFa ? m['fa']! : m['en']!),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setDState(() => selectedMuscle = v ?? 'chest'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text(isFa ? 'انصراف' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameFaCtrl.text.trim().isEmpty &&
                        nameEnCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final fa = nameFaCtrl.text.trim().isNotEmpty
                        ? nameFaCtrl.text.trim()
                        : nameEnCtrl.text.trim();
                    final en = nameEnCtrl.text.trim().isNotEmpty
                        ? nameEnCtrl.text.trim()
                        : fa;

                    ref.read(appDatabaseProvider).addCustomExercise(
                          ExerciseSeedItem(
                            id: 'custom_${_uuid.v4().substring(0, 8)}',
                            nameFa: fa,
                            nameEn: en,
                            targetMuscle: selectedMuscle,
                            equipment: 'custom',
                            imageStartUrl: '',
                            imageEndUrl: '',
                          ),
                        );
                    Navigator.pop(dCtx);
                  },
                  child: Text(isFa ? 'ذخیره در بانک' : 'Save Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// تنظیم ست، تکرار، تمپو، دراپست و یادداشت اختصاصی مربی (Coach Note)
  void _showFastSetTempoConfigurator(
      WorkoutDayPlan activeDay, int exIdx, bool isFa, ThemeData theme) {
    final item = activeDay.exercises[exIdx];
    int setCount = item.sets.length;
    String selectedReps = item.sets.first.reps;
    String selectedTempo = item.sets.first.tempo;
    int selectedRest = item.sets.first.restSeconds;
    bool lastSetDrop = item.sets.last.isDropSet;
    final noteCtrl = TextEditingController(text: item.coachNote);

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
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFa ? item.exerciseNameFa : item.exerciseNameEn,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isFa ? 'تعداد ستها:' : 'Number of Sets:',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isFa ? 'استراحت (ثانیه):' : 'Rest (sec):',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: restPresets.map((sec) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text('${sec}s'),
                                  selected: selectedRest == sec,
                                  onSelected: (_) =>
                                      setModalState(() => selectedRest = sec),
                                ),
                              );
                            }).toList(),
                          ),
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        labelText: isFa
                            ? 'یادداشت و نکته فنی مربی برای این حرکت (چاپ در PDF)'
                            : 'Coach Technical Note (Printed in PDF)',
                        prefixIcon: const Icon(LucideIcons.messageSquarePlus),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          list[exIdx] = item.copyWith(
                            setType:
                                lastSetDrop ? SetType.dropSet : item.setType,
                            sets: newSets,
                            coachNote: noteCtrl.text.trim(),
                          );
                          _updateActiveDayExercises(list);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(LucideIcons.check),
                        label: Text(isFa ? 'اعمال تغییرات' : 'Apply Config'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // تب ۲: رژیم غذایی + دکمه افزودن غذای سفارشی مربی
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 12,
            runSpacing: 6,
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
        const SizedBox(height: 12),
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
                        onPressed: () => _showQuickFoodPicker(slotIdx, isFa),
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
    final db = ref.read(appDatabaseProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setFoodState) {
            final foods = db.getFoodsCatalog();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFa ? 'بانک مواد غذایی' : 'Food Catalog',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _showAddCustomFoodDialog(ctx, isFa);
                          setFoodState(() {});
                        },
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(
                            isFa ? 'غذای سفارشی جدید' : 'Add Custom Food'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (ctx, i) {
                      final food = foods[i];
                      return ListTile(
                        leading: const Icon(LucideIcons.utensilsCrossed),
                        title: Text(isFa ? food['nameFa']! : food['nameEn']!),
                        subtitle:
                            Text(isFa ? food['unitFa']! : food['unitEn']!),
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
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddCustomFoodDialog(BuildContext ctx, bool isFa) async {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: isFa ? '۱۵۰ گرم' : '150g');
    await showDialog(
      context: ctx,
      builder: (dCtx) {
        return AlertDialog(
          title: Text(isFa ? 'افزودن غذای جدید به بانک' : 'New Custom Food'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: isFa ? 'نام ماده غذایی' : 'Food Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unitCtrl,
                decoration: InputDecoration(
                    labelText:
                        isFa ? 'مقدار/واحد (مثلاً ۱۰۰ گرم)' : 'Amount / Unit'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: Text(isFa ? 'انصراف' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                ref.read(appDatabaseProvider).addCustomFood(
                      nameFa: nameCtrl.text.trim(),
                      nameEn: nameCtrl.text.trim(),
                      unitFa: unitCtrl.text.trim(),
                      unitEn: unitCtrl.text.trim(),
                    );
                Navigator.pop(dCtx);
              },
              child: Text(isFa ? 'افزودن' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddAlternativeOption(int slotIdx, int itemIdx, bool isFa) {
    final foods = ref.read(appDatabaseProvider).getFoodsCatalog();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: foods.length,
          itemBuilder: (ctx, i) {
            final alt = foods[i];
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
  // تب ۳: مکملها + دکمه ساخت مکمل سفارشی
  // ===========================================================================
  Widget _buildSupplementTab(bool isFa, ThemeData theme) {
    final suppCatalog = ref.read(appDatabaseProvider).getSupplementsCatalog();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isFa
                  ? 'انتخاب سریع از بانک مکملها:'
                  : 'Quick-Add from Catalog:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _showAddCustomSupplementDialog(isFa),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(isFa ? '+ مکمل سفارشی' : '+ Custom Supp'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suppCatalog.map((sup) {
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

  Future<void> _showAddCustomSupplementDialog(bool isFa) async {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController(text: isFa ? '۱ اسکوپ' : '1 Scoop');
    final timeCtrl =
        TextEditingController(text: isFa ? 'قبل از تمرین' : 'Pre-Workout');

    await showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          title: Text(isFa ? 'افزودن مکمل سفارشی' : 'New Custom Supplement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: isFa ? 'نام مکمل' : 'Supplement Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: doseCtrl,
                decoration: InputDecoration(
                    labelText: isFa ? 'دوز مصرفی' : 'Dosage'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeCtrl,
                decoration: InputDecoration(
                    labelText: isFa ? 'زمان مصرف' : 'Timing'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: Text(isFa ? 'انصراف' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                ref.read(appDatabaseProvider).addCustomSupplement(
                      nameFa: nameCtrl.text.trim(),
                      nameEn: nameCtrl.text.trim(),
                      dosageFa: doseCtrl.text.trim(),
                      dosageEn: doseCtrl.text.trim(),
                      timingFa: timeCtrl.text.trim(),
                      timingEn: timeCtrl.text.trim(),
                    );
                setState(() {});
                Navigator.pop(dCtx);
              },
              child: Text(isFa ? 'ذخیره در بانک' : 'Save'),
            ),
          ],
        );
      },
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFa ? 'مدت اعتبار دوره (هفته):' : 'Program Duration (Weeks):',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
