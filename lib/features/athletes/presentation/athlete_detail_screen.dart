import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../../core/utils/number_parser.dart';
import '../../../core/widgets/maxgym_3d_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../athlete_portal/athlete_portal_screen.dart';
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
                                    image: !kIsWeb && beforePath != null
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
                                    image: !kIsWeb && afterPath != null
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
                        weightKg: weightCtrl.text.toSafeDouble() ??
                            athlete.weightKg,
                        bodyFatPercent: bfCtrl.text.toSafeDouble(),
                        shoulderCm: shoulderCtrl.text.toSafeDouble(),
                        chestCm: chestCtrl.text.toSafeDouble(),
                        waistCm: waistCtrl.text.toSafeDouble(),
                        bicepsCm: bicepsCtrl.text.toSafeDouble(),
                        thighCm: thighCtrl.text.toSafeDouble(),
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.45)),
            ),
            child: TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (sheetCtx) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isFa
                              ? '🔑 مدیریت کد دعوت و دسترسی شاگرد (${athlete.fullName})'
                              : '🔑 Athlete Portal Access Code',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: Icon(LucideIcons.copy,
                              color: theme.colorScheme.primary),
                          title: Text(isFa
                              ? 'کپی کد دعوت فعلی (${athlete.accessCode})'
                              : 'Copy Current Code (${athlete.accessCode})'),
                          subtitle: Text(athlete.isCodeBurned
                              ? (isFa
                                  ? 'وضعیت: استفاده شده (شاگرد رمز عبور شخصی دارد)'
                                  : 'Status: Burned (Password active)')
                              : (isFa
                                  ? 'وضعیت: آماده اولین ورود شاگرد'
                                  : 'Status: Ready for first login')),
                          onTap: () async {
                            await Clipboard.setData(
                                ClipboardData(text: athlete.accessCode));
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isFa
                                      ? 'کد ورود اختصاصی شاگرد کپی شد: ${athlete.accessCode}'
                                      : 'Athlete Access Code copied: ${athlete.accessCode}'),
                                ),
                              );
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(LucideIcons.refreshCw,
                              color: AppColors.warning),
                          title: Text(isFa
                              ? 'صدور کد یکبارمصرف جدید (ریست رمز عبور شاگرد)'
                              : 'Generate New One-Time Code (Reset Password)'),
                          subtitle: Text(isFa
                              ? 'اگر شاگرد رمز عبور و ایمیل خود را فراموش کرده، کد جدید صادر کنید'
                              : 'Use if athlete forgot both email and password'),
                          onTap: () async {
                            final regenerated = db
                                .regenerateOneTimeCodeForAthlete(athlete.id);
                            ref.read(athletesProvider.notifier).refresh();
                            if (regenerated != null) {
                              await Clipboard.setData(ClipboardData(
                                  text: regenerated.accessCode));
                            }
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            setState(() {});
                            if (context.mounted && regenerated != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isFa
                                      ? '✅ کد یکبارمصرف جدید صادر و کپی شد: ${regenerated.accessCode}'
                                      : '✅ New code generated & copied: ${regenerated.accessCode}'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(LucideIcons.keyRound, size: 15),
              label: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  athlete.accessCode,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: isFa ? 'چت متنی با شاگرد' : 'Direct Text Chat',
            icon: const Icon(LucideIcons.messageSquare),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.78,
                  child: PureTextChatView(
                    athlete: athlete,
                    currentSenderRole: 'coach',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: isFa ? 'استوری قبل و بعد (Before/After)' : 'Before/After',
            icon: const Icon(LucideIcons.camera),
            onPressed: () => _showBeforeAfterStorySheet(athlete, isFa),
          ),
          IconButton(
            tooltip: isFa ? 'باز کردن چت واتساپ' : 'Open WhatsApp Chat',
            icon: const Icon(LucideIcons.messageCircle),
            onPressed: () async {
              final cleanPhone = athlete.phone
                  .replaceAll(RegExp(r'^0'), '98')
                  .replaceAll(RegExp(r'\D'), '');
              final waUri = Uri.parse('https://wa.me/$cleanPhone');
              try {
                if (await canLaunchUrl(waUri)) {
                  await launchUrl(waUri, mode: LaunchMode.externalApplication);
                  return;
                }
              } catch (_) {}
              await Clipboard.setData(
                  ClipboardData(text: 'https://wa.me/$cleanPhone'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFa
                        ? 'لینک مستقیم واتساپ شاگرد کپی شد.'
                        : 'WhatsApp direct link copied.'),
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
              text: isFa ? 'برنامه‌ها (${programs.length})' : 'Programs',
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBioAndMacrosTab(athlete, bio, isFa, theme),
              _buildAnalyticsChartsTab(athlete, logs, isFa, theme),
              _buildProgramsTab(athlete, programs, isFa, theme),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_athlete_detail_unique',
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
    final primary = theme.colorScheme.primary;
    final bmiNorm = ((bio.bmi - 15.0) / 22.0).clamp(0.05, 0.95);
    final whtrVal = bio.whtr ?? 0.46;
    final whtrNorm = ((whtrVal - 0.35) / 0.30).clamp(0.05, 0.95);

    Widget microGlassBox(
        String title, String value, String sub, Color color, IconData icon) {
      return Expanded(
        child: MaxGymGlassCard(
          accentColor: color,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ۱. نوار شیشهای شناسنامه بیومتریک ورزشکار (با جهت صحیح واحدها)
        MaxGymGlassCard(
          accentColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
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
                const Divider(height: 24, color: Colors.white12),
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
        const SizedBox(height: 16),

        // ۲. گیجهای طیفی مدرن برای BMI و WHtR
        Row(
          children: [
            Expanded(
              child: MaxGymSpectrumGauge(
                title: isFa ? 'شاخص توده بدنی (BMI)' : 'Body Mass Index (BMI)',
                valueText: bio.bmi.toString(),
                statusText: isFa ? bio.bmiCategoryFa : bio.bmiCategoryEn,
                normalizedPosition: bmiNorm,
                accentColor: primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: MaxGymSpectrumGauge(
                title:
                    isFa ? 'نسبت کمر به قد (WHtR)' : 'Waist-to-Height (WHtR)',
                valueText: bio.whtr?.toString() ?? '--',
                statusText: isFa ? bio.whtrStatusFa : bio.whtrStatusEn,
                normalizedPosition: whtrNorm,
                accentColor: Colors.cyanAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ۳. حلقههای نئونی سهگانه ماکرو و کالری (Apple Fitness+ / Whoop Style)
        Text(
          isFa
              ? 'مقادیر علمی درشتمغذیها و ریزمغذیها (بر اساس هدف شاگرد):'
              : 'Scientific Daily Macro & Micro Targets:',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 10),
        MaxGymNeonMacroRings(
          targetCalories: bio.targetCalories,
          proteinGrams: bio.proteinGrams,
          carbsGrams: bio.carbsGrams,
          fatGrams: bio.fatGrams,
          isFa: isFa,
        ),
        const SizedBox(height: 14),

        // ۴. تفکیک متابولیسم پایه و تثبیت
        MaxGymGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _kcalColumn(isFa ? 'متابولیسم پایه (BMR)' : 'BMR',
                  '${bio.bmrKcal} kcal', Colors.white70),
              Container(width: 1, height: 34, color: Colors.white12),
              _kcalColumn(isFa ? 'کالری تثبیت (TDEE)' : 'Maintenance',
                  '${bio.tdeeKcal} kcal', Colors.orangeAccent),
              Container(width: 1, height: 34, color: Colors.white12),
              _kcalColumn(isFa ? 'کالری هدف روزانه' : 'Target Calories',
                  '${bio.targetCalories} kcal', primary),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ۵. کارتهای شیشهای فیبر و هیدراتاسیون
        Row(
          children: [
            microGlassBox(
              isFa ? 'فیبر روزانه (Fiber)' : 'Dietary Fiber',
              '${bio.fiberGrams} g',
              isFa ? 'سلامت گوارش و جذب' : 'Gut & Insulin Health',
              AppColors.success,
              LucideIcons.leaf,
            ),
            const SizedBox(width: 14),
            microGlassBox(
              isFa ? 'آب مصرفی (Hydration)' : 'Daily Water',
              '${bio.waterLiters} L',
              isFa ? 'شامل ۵۰۰ میلیلیتر تمرین' : 'Includes workout sweat',
              const Color(0xFF29B6F6),
              LucideIcons.glassWater,
            ),
          ],
        ),
        const SizedBox(height: 22),

        // ۶. آخرین گزارشهای تمرین ثبتشده توسط شاگرد
        Text(
          isFa
              ? '📊 آخرین گزارشهای تمرین و رکوردهای ثبتشده توسط شاگرد:'
              : '📊 Athlete Logged Workout Sessions & PRs:',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (ctx) {
            final workoutLogs = ref
                .read(appDatabaseProvider)
                .getWorkoutLogsForAthlete(athlete.id);
            if (workoutLogs.isEmpty) {
              return MaxGymGlassCard(
                padding: const EdgeInsets.all(18),
                child: Text(
                  isFa
                      ? 'شاگرد هنوز گزارش تمرینی از پنل خود ارسال نکرده است.'
                      : 'No workout sessions logged by athlete yet.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              );
            }
            return Column(
              children: workoutLogs.take(5).map((wLog) {
                final weightsSummary = wLog.exerciseWeightsKg.entries
                    .map((e) => '${e.value}kg')
                    .join(' | ');
                return MaxGymGlassCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  accentColor: AppColors.success,
                  padding: const EdgeInsets.all(10),
                  child: ListTile(
                    leading: const Icon(LucideIcons.trophy,
                        color: AppColors.success),
                    title: Text(
                      isFa
                          ? 'جلسه روز ${wLog.dayNumber} - تاریخ: ${_formatShamsi(wLog.loggedAt)}'
                          : 'Day ${wLog.dayNumber} - ${wLog.loggedAt.toString().substring(0, 10)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      isFa
                          ? '💧 آب: ${wLog.waterGlasses} لیوان | وزنه ثبتشده: ${weightsSummary.isEmpty ? "تکمیل شده" : weightsSummary}'
                          : '💧 Water: ${wLog.waterGlasses} glasses | Weights: $weightsSummary',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildAnalyticsChartsTab(AthleteEntity athlete,
      List<MeasurementLogEntity> logs, bool isFa, ThemeData theme) {
    final latest = logs.isNotEmpty ? logs.last : null;
    final baseline = logs.isNotEmpty ? logs.first : null;
    final primary = theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isFa ? 'روند تغییرات وزن (کیلوگرم)' : 'Weight Progression (kg)',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            ElevatedButton.icon(
              onPressed: () => _showNewCheckInDialog(athlete, latest),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(isFa ? 'ثبت سایز جدید' : 'Add Check-In'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        MaxGymGlassCard(
          accentColor: primary,
          padding: const EdgeInsets.fromLTRB(16, 28, 24, 16),
          child: SizedBox(
            height: 220,
            child: logs.isEmpty
                ? Center(
                    child: Text(isFa
                        ? 'هنوز سایزگیری ثبت نشده است'
                        : 'No measurements yet'))
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: logs.length > 1
                          ? (logs.length - 1).toDouble()
                          : 1.0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white.withOpacity(0.08),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (_) => FlLine(
                          color: Colors.white.withOpacity(0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (val, _) => Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                val.toStringAsFixed(0),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1, // <-- رفع قطعی باگ تکرار تاریخ 11/10
                            getTitlesWidget: (val, meta) {
                              if (val != val.roundToDouble()) {
                                return const SizedBox.shrink();
                              }
                              final idx = val.toInt();
                              if (idx < 0 || idx >= logs.length) {
                                return const SizedBox.shrink();
                              }
                              final d = logs[idx].recordedAt;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '${d.month}/${d.day}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: logs.length == 1
                              ? [
                                  FlSpot(0, logs.first.weightKg),
                                  FlSpot(1, logs.first.weightKg),
                                ]
                              : List.generate(
                                  logs.length,
                                  (i) => FlSpot(i.toDouble(), logs[i].weightKg),
                                ),
                          isCurved: true,
                          color: primary,
                          barWidth: 3.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: primary,
                              strokeWidth: 2,
                              strokeColor: Colors.black,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                primary.withOpacity(0.32),
                                primary.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 22),
        if (baseline != null &&
            latest != null &&
            (latest.chestCm != null ||
                latest.waistCm != null ||
                latest.bicepsCm != null)) ...[
          Text(
            isFa
                ? 'نمودار راداری تقارن و تغییرات سایز (شروع در برابر فعلی)'
                : 'Anthropometric Radar (Baseline vs. Latest)',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),
          MaxGymGlassCard(
            accentColor: primary,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 260,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  tickCount: 3,
                  ticksTextStyle: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 0,
                  ),
                  radarBorderData:
                      BorderSide(color: Colors.white.withOpacity(0.18)),
                  tickBorderData:
                      BorderSide(color: Colors.white.withOpacity(0.10)),
                  gridBorderData:
                      BorderSide(color: Colors.white.withOpacity(0.12)),
                  getTitle: (index, angle) {
                    final titlesFa = ['سرشانه', 'سینه', 'کمر', 'بازو', 'ران'];
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
                      fillColor: Colors.grey.withOpacity(0.18),
                      borderColor: Colors.white38,
                      entryRadius: 2.5,
                      dataEntries: [
                        RadarEntry(value: baseline.shoulderCm ?? 100),
                        RadarEntry(value: baseline.chestCm ?? 95),
                        RadarEntry(value: baseline.waistCm ?? 85),
                        RadarEntry(value: baseline.bicepsCm ?? 35),
                        RadarEntry(value: baseline.thighCm ?? 55),
                      ],
                    ),
                    RadarDataSet(
                      fillColor: primary.withOpacity(0.30),
                      borderColor: primary,
                      borderWidth: 2.5,
                      entryRadius: 4,
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
                            value: latest.bicepsCm ?? baseline.bicepsCm ?? 35),
                        RadarEntry(
                            value: latest.thighCm ?? baseline.thighCm ?? 55),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          isFa ? 'تاریخچه کامل سایزگیری‌ها:' : 'Measurement History Logs:',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 10),
        ...logs.reversed.map((l) {
          return MaxGymGlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: primary.withOpacity(0.18),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${l.weightKg.toStringAsFixed(0)}kg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                ),
              ),
              title: Text(
                isFa
                    ? 'تاریخ: ${_formatShamsi(l.recordedAt)}'
                    : 'Date: ${l.recordedAt.toString().substring(0, 10)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${l.chestCm != null ? "Chest: ${l.chestCm}cm | " : ""}'
                  '${l.waistCm != null ? "Waist: ${l.waistCm}cm | " : ""}'
                  '${l.bicepsCm != null ? "Arm: ${l.bicepsCm}cm | " : ""}'
                  '${l.bodyFatPercent != null ? "BF: ${l.bodyFatPercent}%" : ""}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildProgramsTab(AthleteEntity athlete,
      List<FullProgramEntity> programs, bool isFa, ThemeData theme) {
    final db = ref.read(appDatabaseProvider);
    final primary = theme.colorScheme.primary;

    if (programs.isEmpty) {
      return Center(
        child: MaxGymGlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.clipboardX, size: 56, color: primary),
              const SizedBox(height: 12),
              Text(
                isFa
                    ? 'هنوز برنامه‌ای برای این شاگرد ثبت نشده است.'
                    : 'No programs assigned yet.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: programs.length,
      itemBuilder: (context, idx) {
        final p = programs[idx];
        final remDays = p.remainingDays;
        final isExpired = remDays <= 0;

        return MaxGymGlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          accentColor: isExpired ? AppColors.danger : primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                  ),
                  IconButton(
                    tooltip: isFa ? 'خروجی PDF اختصاصی' : 'Export PDF',
                    icon: Icon(LucideIcons.fileOutput, color: primary, size: 24),
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
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isExpired
                              ? AppColors.danger
                              : (remDays <= 5
                                  ? AppColors.warning
                                  : AppColors.success))
                          .withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isExpired
                          ? (isFa ? 'منقضی شده' : 'Expired')
                          : (isFa
                              ? '$remDays روز باقیمانده'
                              : '$remDays days left'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isFa
                            ? 'بدهکار: ${p.remainingDebt.toPriceFormat()} تومان'
                            : 'Unpaid: ${p.remainingDebt.toPriceFormat()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24, color: Colors.white12),
              Wrap(
                spacing: 10,
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
        );
      },
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF72C832)),
        const SizedBox(width: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _kcalColumn(String label, String val, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            val,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
