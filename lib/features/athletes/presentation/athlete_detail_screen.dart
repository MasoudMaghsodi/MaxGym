import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../../data/local/app_database.dart';
import '../../workout_builder/presentation/master_program_builder_screen.dart';
import '../domain/scientific_bio_calculator.dart';
import 'athlete_onboarding_sheet.dart';
import 'athletes_provider.dart';

class AthleteDetailScreen extends ConsumerStatefulWidget {
  final String athleteId;
  final void Function(AthleteEntity athlete)? onOpenWorkoutBuilder;
  final void Function(AthleteEntity athlete, FullProgramEntity program)?
      onExportPdf;

  const AthleteDetailScreen({
    super.key,
    required this.athleteId,
    this.onOpenWorkoutBuilder,
    this.onExportPdf,
  });

  @override
  ConsumerState<AthleteDetailScreen> createState() =>
      _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends ConsumerState<AthleteDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatShamsi(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  /// باز کردن طراح برنامه در حالت «ویرایش برنامه فعلی» یا «کپی برای دوره جدید»
  Future<void> _openEditorOrClone({
    required AthleteEntity athlete,
    required FullProgramEntity program,
    required bool isEditingExisting,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MasterProgramBuilderScreen(
          athlete: athlete,
          initialProgramOrTemplate: program,
          isEditingExisting: isEditingExisting,
          onSavedAndExportPdf: widget.onExportPdf,
        ),
      ),
    );
    setState(() {});
  }

  /// ابزار مقایسه تصویری قبل و بعد (Before / After Story Comparison) بدون اشغال فضای ابری
  void _showBeforeAfterStorySheet(AthleteEntity athlete, bool isFa) {
    String? beforePath;
    String? afterPath;
    final branding = ref.read(brandingProvider);
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFa
                        ? '📸 مقایسه تصویری پیشرفت (Before / After)'
                        : '📸 Before & After Transformation',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${branding.gymName} | ${branding.coachName}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final img = await picker.pickImage(
                                      source: ImageSource.gallery);
                                  if (img != null) {
                                    setSheetState(() => beforePath = img.path);
                                  }
                                },
                                child: Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                    image: beforePath != null
                                        ? DecorationImage(
                                            image: FileImage(File(beforePath!)),
                                            fit: BoxFit.cover)
                                        : null,
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.black54,
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      isFa ? 'قبل (Before)' : 'BEFORE',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final img = await picker.pickImage(
                                      source: ImageSource.gallery);
                                  if (img != null) {
                                    setSheetState(() => afterPath = img.path);
                                  }
                                },
                                child: Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                    image: afterPath != null
                                        ? DecorationImage(
                                            image: FileImage(File(afterPath!)),
                                            fit: BoxFit.cover)
                                        : null,
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.black54,
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      isFa ? 'بعد (After)' : 'AFTER',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${athlete.fullName} | ${branding.socialHandle}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (beforePath != null && afterPath != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        Share.shareXFiles(
                          [XFile(beforePath!), XFile(afterPath!)],
                          text:
                              '🔥 تغییرات فوقالعاده ${athlete.fullName} تحت نظر ${branding.coachName} (${branding.gymName}) 💪',
                        );
                      },
                      icon: const Icon(LucideIcons.share2),
                      label: Text(isFa
                          ? 'اشتراکگذاری تصاویر برای استوری'
                          : 'Share Transformation'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showNewCheckInDialog(
      AthleteEntity athlete, MeasurementLogEntity? latest) async {
    final isFa = AppStrings.of(context).isFa;
    final weightCtrl =
        TextEditingController(text: athlete.weightKg.toStringAsFixed(1));
    final bfCtrl = TextEditingController(
        text: latest?.bodyFatPercent?.toStringAsFixed(1) ?? '');
    final waistCtrl =
        TextEditingController(text: latest?.waistCm?.toStringAsFixed(1) ?? '');
    final chestCtrl =
        TextEditingController(text: latest?.chestCm?.toStringAsFixed(1) ?? '');
    final bicepsCtrl =
        TextEditingController(text: latest?.bicepsCm?.toStringAsFixed(1) ?? '');
    final thighCtrl =
        TextEditingController(text: latest?.thighCm?.toStringAsFixed(1) ?? '');
    final shoulderCtrl = TextEditingController(
        text: latest?.shoulderCm?.toStringAsFixed(1) ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFa
                      ? 'ثبت سایزگیری جدید (مقایسه پیشرفت)'
                      : 'New Anthropometric Check-In',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: isFa ? 'وزن جدید (kg)' : 'Weight (kg)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: bfCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: isFa ? 'درصد چربی (%)' : 'Body Fat (%)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: shoulderCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: isFa ? 'سرشانه (cm)' : 'Shoulders (cm)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: chestCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: isFa ? 'سینه (cm)' : 'Chest (cm)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: waistCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: isFa ? 'دور کمر (cm)' : 'Waist (cm)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: bicepsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: isFa ? 'بازو (cm)' : 'Biceps (cm)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: thighCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: isFa ? 'ران (cm)' : 'Thigh (cm)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      final log = MeasurementLogEntity(
                        id: const Uuid().v4(),
                        athleteId: athlete.id,
                        recordedAt: now,
                        weightKg:
                            double.tryParse(weightCtrl.text) ?? athlete.weightKg,
                        bodyFatPercent: double.tryParse(bfCtrl.text),
                        shoulderCm: double.tryParse(shoulderCtrl.text),
                        chestCm: double.tryParse(chestCtrl.text),
                        waistCm: double.tryParse(waistCtrl.text),
                        bicepsCm: double.tryParse(bicepsCtrl.text),
                        thighCm: double.tryParse(thighCtrl.text),
                        updatedAt: now,
                      );
                      ref
                          .read(athletesProvider.notifier)
                          .addMeasurementCheckIn(log);
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                    icon: const Icon(LucideIcons.check),
                    label: Text(isFa ? 'ثبت در نمودار پیشرفت' : 'Save Check-In'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    ref.watch(athletesProvider);
    final athlete = db.getAthleteById(widget.athleteId);
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);

    if (athlete == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Athlete not found')),
      );
    }

    final logs = db.getMeasurementsForAthlete(athlete.id);
    final latestLog = logs.isNotEmpty ? logs.last : null;
    final programs = db.getProgramsForAthlete(athlete.id);

    final bio = ScientificBioCalculator.analyze(
      gender: athlete.gender,
      age: athlete.age,
      heightCm: athlete.heightCm,
      weightKg: athlete.weightKg,
      fitnessGoal: athlete.fitnessGoal,
      bodyFatPercent: latestLog?.bodyFatPercent,
      waistCm: latestLog?.waistCm,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(athlete.fullName),
        actions: [
          IconButton(
            tooltip: isFa ? 'استوری قبل و بعد (Before/After)' : 'Before/After',
            icon: const Icon(LucideIcons.camera),
            onPressed: () => _showBeforeAfterStorySheet(athlete, isFa),
          ),
          IconButton(
            tooltip: isFa ? 'کپی لینک مستقیم چت واتساپ' : 'WhatsApp Direct Link',
            icon: const Icon(LucideIcons.messageCircle),
            onPressed: () async {
              final cleanPhone =
                  athlete.phone.replaceAll(RegExp(r'^0'), '98');
              final waLink = 'https://wa.me/$cleanPhone';
              await Clipboard.setData(ClipboardData(text: waLink));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFa
                        ? 'لینک مستقیم واتساپ شاگرد کپی شد: $waLink'
                        : 'WhatsApp direct link copied: $waLink'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.edit3),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    AthleteOnboardingSheet(existingAthlete: athlete),
              );
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(LucideIcons.flame, size: 18),
              text: isFa ? 'تحلیل علمی و ماکرو' : 'Bio & Macros',
            ),
            Tab(
              icon: const Icon(LucideIcons.lineChart, size: 18),
              text: isFa ? 'نمودار سایزها' : 'Progress Charts',
            ),
            Tab(
              icon: const Icon(LucideIcons.clipboardList, size: 18),
              text: isFa ? 'برنامهها (${programs.length})' : 'Programs',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBioAndMacrosTab(athlete, bio, isFa, theme),
          _buildAnalyticsChartsTab(athlete, logs, isFa, theme),
          _buildProgramsTab(athlete, programs, isFa, theme),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.onOpenWorkoutBuilder != null) {
            widget.onOpenWorkoutBuilder!(athlete);
          }
        },
        icon: const Icon(LucideIcons.plusCircle),
        label: Text(isFa ? 'طراحی برنامه جدید' : 'New Program'),
      ),
    );
  }

  Widget _buildBioAndMacrosTab(
      AthleteEntity athlete, BioAnalysisResult bio, bool isFa, ThemeData theme) {
    Widget macroBox(
        String title, String value, String sub, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _infoBadge(LucideIcons.ruler,
                        '${athlete.heightCm.toStringAsFixed(0)} cm'),
                    _infoBadge(LucideIcons.scale,
                        '${athlete.weightKg.toStringAsFixed(1)} kg'),
                    _infoBadge(LucideIcons.calendar,
                        '${athlete.age} ${isFa ? "ساله" : "yrs"}'),
                    _infoBadge(LucideIcons.activity, bio.formulaUsed),
                  ],
                ),
                if (athlete.injuryTags.isNotEmpty) ...[
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: athlete.injuryTags.map((tag) {
                      return Chip(
                        avatar: const Icon(LucideIcons.alertTriangle,
                            size: 16, color: AppColors.warning),
                        label: Text(tag.toUpperCase()),
                        backgroundColor: AppColors.warning.withOpacity(0.15),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            macroBox(
              'BMI',
              bio.bmi.toString(),
              isFa ? bio.bmiCategoryFa : bio.bmiCategoryEn,
              theme.colorScheme.primary,
              LucideIcons.gauge,
            ),
            const SizedBox(width: 12),
            macroBox(
              isFa ? 'نسبت کمر به قد (WHtR)' : 'Waist-to-Height (WHtR)',
              bio.whtr?.toString() ?? '--',
              isFa ? bio.whtrStatusFa : bio.whtrStatusEn,
              Colors.cyanAccent,
              LucideIcons.shieldCheck,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _kcalColumn(isFa ? 'متابولیسم پایه (BMR)' : 'BMR',
                    '${bio.bmrKcal}', Colors.grey),
                _kcalColumn(isFa ? 'کالری تثبیت (TDEE)' : 'Maintenance',
                    '${bio.tdeeKcal}', Colors.orangeAccent),
                _kcalColumn(
                    isFa ? 'کالری هدف روزانه' : 'Target Calories',
                    '${bio.targetCalories} kcal',
                    theme.colorScheme.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isFa
              ? 'مقادیر علمی درشتمغذیها و ریزمغذیها (بر اساس هدف شاگرد):'
              : 'Scientific Daily Macro & Micro Targets:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            macroBox(
              isFa ? 'پروتئین (Protein)' : 'Protein',
              '${bio.proteinGrams} g',
              '${bio.proteinGrams * 4} kcal',
              const Color(0xFFFF5252),
              LucideIcons.beef,
            ),
            const SizedBox(width: 10),
            macroBox(
              isFa ? 'کربوهیدرات (Carbs)' : 'Net Carbs',
              '${bio.carbsGrams} g',
              '${bio.carbsGrams * 4} kcal',
              const Color(0xFFFFB300),
              LucideIcons.wheat,
            ),
            const SizedBox(width: 10),
            macroBox(
              isFa ? 'چربی سالم (Fats)' : 'Healthy Fats',
              '${bio.fatGrams} g',
              '${bio.fatGrams * 9} kcal',
              const Color(0xFFAB47BC),
              LucideIcons.droplet,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            macroBox(
              isFa ? 'فیبر روزانه (Fiber)' : 'Dietary Fiber',
              '${bio.fiberGrams} g',
              isFa ? 'سلامت گوارش و جذب' : 'Gut & Insulin Health',
              AppColors.success,
              LucideIcons.leaf,
            ),
            const SizedBox(width: 10),
            macroBox(
              isFa ? 'آب مصرفی (Hydration)' : 'Daily Water',
              '${bio.waterLiters} L',
              isFa ? 'شامل ۵۰۰ میلیلیتر تمرین' : 'Includes workout sweat',
              const Color(0xFF29B6F6),
              LucideIcons.glassWater,
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildAnalyticsChartsTab(AthleteEntity athlete,
      List<MeasurementLogEntity> logs, bool isFa, ThemeData theme) {
    final latest = logs.isNotEmpty ? logs.last : null;
    final baseline = logs.isNotEmpty ? logs.first : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isFa ? 'روند تغییرات وزن (کیلوگرم)' : 'Weight Progression (kg)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton.icon(
              onPressed: () => _showNewCheckInDialog(athlete, latest),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(isFa ? 'ثبت سایز جدید' : 'Add Check-In'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 20, 12),
            child: SizedBox(
              height: 200,
              child: logs.isEmpty
                  ? Center(
                      child: Text(isFa
                          ? 'هنوز سایزگیری ثبت نشده است'
                          : 'No measurements yet'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= logs.length) {
                                  return const SizedBox.shrink();
                                }
                                final d = logs[idx].recordedAt;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${d.month}/${d.day}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              logs.length,
                              (i) => FlSpot(i.toDouble(), logs[i].weightKg),
                            ),
                            isCurved: true,
                            color: theme.colorScheme.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color:
                                  theme.colorScheme.primary.withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (baseline != null &&
            latest != null &&
            (latest.chestCm != null ||
                latest.waistCm != null ||
                latest.bicepsCm != null)) ...[
          Text(
            isFa
                ? 'نمودار راداری تقارن و تغییرات سایز (شروع در برابر فعلی)'
                : 'Anthropometric Radar (Baseline vs. Latest)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 240,
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    getTitle: (index, angle) {
                      final titlesFa = [
                        'سرشانه',
                        'سینه',
                        'کمر',
                        'بازو',
                        'ران'
                      ];
                      final titlesEn = [
                        'Shoulder',
                        'Chest',
                        'Waist',
                        'Biceps',
                        'Thigh'
                      ];
                      return RadarChartTitle(
                        text: isFa ? titlesFa[index] : titlesEn[index],
                      );
                    },
                    dataSets: [
                      RadarDataSet(
                        fillColor: Colors.grey.withOpacity(0.2),
                        borderColor: Colors.grey,
                        entryRadius: 2,
                        dataEntries: [
                          RadarEntry(value: baseline.shoulderCm ?? 100),
                          RadarEntry(value: baseline.chestCm ?? 95),
                          RadarEntry(value: baseline.waistCm ?? 85),
                          RadarEntry(value: baseline.bicepsCm ?? 35),
                          RadarEntry(value: baseline.thighCm ?? 55),
                        ],
                      ),
                      RadarDataSet(
                        fillColor: theme.colorScheme.primary.withOpacity(0.25),
                        borderColor: theme.colorScheme.primary,
                        entryRadius: 3,
                        dataEntries: [
                          RadarEntry(
                              value: (latest.shoulderCm ??
                                      baseline.shoulderCm ??
                                      100) +
                                  0.1),
                          RadarEntry(
                              value: latest.chestCm ?? baseline.chestCm ?? 95),
                          RadarEntry(
                              value: latest.waistCm ?? baseline.waistCm ?? 85),
                          RadarEntry(
                              value:
                                  latest.bicepsCm ?? baseline.bicepsCm ?? 35),
                          RadarEntry(
                              value: latest.thighCm ?? baseline.thighCm ?? 55),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          isFa ? 'تاریخچه کامل سایزگیریها:' : 'Measurement History Logs:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...logs.reversed.map((l) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                child: Text(
                  '${l.weightKg.toStringAsFixed(0)}k',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                ),
              ),
              title: Text(
                isFa
                    ? 'تاریخ: ${_formatShamsi(l.recordedAt)}'
                    : 'Date: ${l.recordedAt.toString().substring(0, 10)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${l.chestCm != null ? "Chest: ${l.chestCm}cm | " : ""}'
                '${l.waistCm != null ? "Waist: ${l.waistCm}cm | " : ""}'
                '${l.bicepsCm != null ? "Arm: ${l.bicepsCm}cm | " : ""}'
                '${l.bodyFatPercent != null ? "BF: ${l.bodyFatPercent}%" : ""}',
              ),
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  /// تب ۳: لیست برنامهها با دکمههای «ویرایش برنامه»، «کپی برای دوره جدید»، «تسویه بدهی» و «PDF»
  Widget _buildProgramsTab(AthleteEntity athlete,
      List<FullProgramEntity> programs, bool isFa, ThemeData theme) {
    final db = ref.read(appDatabaseProvider);

    if (programs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.clipboardX, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(isFa
                ? 'هنوز برنامهای برای این شاگرد ثبت نشده است.'
                : 'No programs assigned yet.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: programs.length,
      itemBuilder: (context, idx) {
        final p = programs[idx];
        final remDays = p.remainingDays;
        final isExpired = remDays <= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      tooltip: isFa ? 'خروجی PDF اختصاصی' : 'Export PDF',
                      icon: Icon(LucideIcons.fileOutput,
                          color: theme.colorScheme.primary, size: 24),
                      onPressed: () {
                        if (widget.onExportPdf != null) {
                          widget.onExportPdf!(athlete, p);
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  isFa
                      ? 'شروع: ${_formatShamsi(p.startDate)} | مدت: ${p.durationWeeks} هفته'
                      : 'Start: ${p.startDate.toString().substring(0, 10)} (${p.durationWeeks} Weeks)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isExpired
                                ? AppColors.danger
                                : (remDays <= 5
                                    ? AppColors.warning
                                    : AppColors.success))
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isExpired
                            ? (isFa ? 'منقضی شده' : 'Expired')
                            : (isFa
                                ? '$remDays روز باقیمانده'
                                : '$remDays days left'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? AppColors.danger
                              : (remDays <= 5
                                  ? AppColors.warning
                                  : AppColors.success),
                        ),
                      ),
                    ),
                    if (p.remainingDebt > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isFa
                              ? 'بدهکار: ${p.remainingDebt.toStringAsFixed(0)} تومان'
                              : 'Unpaid: ${p.remainingDebt.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openEditorOrClone(
                        athlete: athlete,
                        program: p,
                        isEditingExisting: true,
                      ),
                      icon: const Icon(LucideIcons.edit, size: 16),
                      label: Text(isFa ? 'ویرایش برنامه' : 'Edit Plan'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditorOrClone(
                        athlete: athlete,
                        program: p,
                        isEditingExisting: false,
                      ),
                      icon: const Icon(LucideIcons.copy, size: 16),
                      label: Text(isFa ? 'کپی برای دوره جدید' : 'Clone Plan'),
                    ),
                    if (p.remainingDebt > 0)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          db.settleProgramDebt(p.id);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFa
                                  ? 'بدهی برنامه «${p.title}» با موفقیت تسویه شد.'
                                  : 'Debt settled successfully for ${p.title}'),
                            ),
                          );
                        },
                        icon: const Icon(LucideIcons.checkCheck, size: 16),
                        label: Text(isFa ? 'تسویه بدهی' : 'Settle Debt'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _kcalColumn(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
