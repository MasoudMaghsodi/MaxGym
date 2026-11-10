import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/maxgym_3d_widgets.dart';
import '../../../data/local/app_database.dart';
import '../domain/scientific_bio_calculator.dart';
import 'athlete_detail_screen.dart';
import 'athlete_onboarding_sheet.dart';
import 'athletes_provider.dart';

enum AthleteQuickFilter { all, unpaidDebt, expiringProgram }

class AthletesListScreen extends ConsumerStatefulWidget {
  final void Function(AthleteEntity athlete)? onOpenWorkoutBuilder;
  final void Function(AthleteEntity athlete, FullProgramEntity program)?
      onExportPdf;

  const AthletesListScreen({
    super.key,
    this.onOpenWorkoutBuilder,
    this.onExportPdf,
  });

  @override
  ConsumerState<AthletesListScreen> createState() =>
      _AthletesListScreenState();
}

class _AthletesListScreenState extends ConsumerState<AthletesListScreen> {
  AthleteQuickFilter _activeFilter = AthleteQuickFilter.all;

  void _show1RMCalculatorDialog(BuildContext context, bool isFa) {
    final weightCtrl = TextEditingController(text: '100');
    final repsCtrl = TextEditingController(text: '8');
    double result = 126.7;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void recalc() {
              final w = double.tryParse(weightCtrl.text) ?? 0;
              final r = int.tryParse(repsCtrl.text) ?? 0;
              setDialogState(() {
                result = ScientificBioCalculator.calculateOneRepMax(w, r);
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(LucideIcons.calculator),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(isFa
                        ? 'ماشینحساب رکورد ۱ تکرار (1RM)'
                        : '1-Rep Max (1RM) Calculator'),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => recalc(),
                          decoration: InputDecoration(
                            labelText: isFa ? 'وزنه (kg)' : 'Weight (kg)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: repsCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => recalc(),
                          decoration: InputDecoration(
                            labelText: isFa ? 'تعداد تکرار' : 'Reps',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '100% (1RM): $result kg',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '85% (6 Reps): ${(result * 0.85).toStringAsFixed(1)} kg  |  '
                      '75% (10 Reps): ${(result * 0.75).toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isFa ? 'بستن' : 'Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportJsonBackup(BuildContext context, bool isFa) async {
    final db = ref.read(appDatabaseProvider);
    final jsonStr = db.exportFullDatabaseToJson();

    if (kIsWeb) {
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'maxgym_full_backup.json',
            mimeType: 'application/json',
          ),
        ],
        text: isFa
            ? 'فایل پشتیبان کامل دیتابیس ورزشکاران و برنامهها (JSON)'
            : 'MAX GYM Full Database Backup (JSON)',
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, 'maxgym_full_backup.json'));
    await file.writeAsString(jsonStr, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, name: 'maxgym_full_backup.json')],
      text: isFa
          ? 'فایل پشتیبان کامل دیتابیس ورزشکاران و برنامهها (JSON)'
          : 'MAX GYM Full Database Backup (JSON)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseAthletes = ref.watch(filteredAthletesProvider);
    final db = ref.watch(appDatabaseProvider);
    final s = AppStrings.of(context);
    final isFa = s.isFa;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final athletes = baseAthletes.where((a) {
      if (_activeFilter == AthleteQuickFilter.all) return true;
      final progs = db.getProgramsForAthlete(a.id);
      if (_activeFilter == AthleteQuickFilter.unpaidDebt) {
        return progs.any((p) => p.remainingDebt > 0);
      }
      if (_activeFilter == AthleteQuickFilter.expiringProgram) {
        return progs.any((p) => p.remainingDays <= 5);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.tr('athletes')} (${athletes.length})'),
        actions: [
          IconButton(
            tooltip: isFa
                ? 'خروجی فایل بکاپ آفلاین (JSON)'
                : 'Export Offline JSON Backup',
            icon: const Icon(LucideIcons.databaseBackup),
            onPressed: () => _exportJsonBackup(context, isFa),
          ),
          IconButton(
            tooltip: isFa ? 'ماشینحساب 1RM' : '1RM Calculator',
            icon: const Icon(LucideIcons.calculator),
            onPressed: () => _show1RMCalculatorDialog(context, isFa),
          ),
        ],
      ),
      body: Column(
        children: [
          if (baseAthletes.isNotEmpty ||
              ref.watch(athleteSearchQueryProvider).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: TextField(
                onChanged: (v) =>
                    ref.read(athleteSearchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: isFa
                      ? 'جستجوی نام، شماره موبایل یا کد شاگرد (PC-XXXXXX)...'
                      : 'Search athlete name, phone, or access code...',
                  prefixIcon: const Icon(LucideIcons.search),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(isFa ? 'همه ورزشکاران' : 'All Athletes'),
                  selected: _activeFilter == AthleteQuickFilter.all,
                  onSelected: (_) =>
                      setState(() => _activeFilter = AthleteQuickFilter.all),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(isFa ? '💰 بدهکاران شهریه' : '💰 Unpaid Debt'),
                  selected: _activeFilter == AthleteQuickFilter.unpaidDebt,
                  onSelected: (_) => setState(
                      () => _activeFilter = AthleteQuickFilter.unpaidDebt),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label:
                      Text(isFa ? '⏳ دوره رو به اتمام' : '⏳ Expiring Programs'),
                  selected:
                      _activeFilter == AthleteQuickFilter.expiringProgram,
                  onSelected: (_) => setState(() =>
                      _activeFilter = AthleteQuickFilter.expiringProgram),
                ),
              ],
            ),
          ),
          Expanded(
            child: athletes.isEmpty
                ? Center(
                    child: Text(isFa
                        ? 'هیچ ورزشکاری با این فیلتر یافت نشد.'
                        : 'No athletes match this filter.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: athletes.length,
                    itemBuilder: (context, index) {
                      final a = athletes[index];
                      final bio = ScientificBioCalculator.analyze(
                        gender: a.gender,
                        age: a.age,
                        heightCm: a.heightCm,
                        weightKg: a.weightKg,
                        fitnessGoal: a.fitnessGoal,
                      );

                      return Dismissible(
                        key: ValueKey(a.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(LucideIcons.trash2,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: Text(
                                  isFa ? 'حذف ورزشکار؟' : 'Delete Athlete?'),
                              content: Text(isFa
                                  ? 'آیا از حذف ${a.fullName} اطمینان دارید؟'
                                  : 'Are you sure you want to delete ${a.fullName}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: Text(isFa ? 'انصراف' : 'Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: Text(isFa ? 'حذف' : 'Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          ref
                              .read(athletesProvider.notifier)
                              .deleteAthlete(a.id);
                        },
                        child: MaxGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AthleteDetailScreen(
                                    athleteId: a.id,
                                    onOpenWorkoutBuilder:
                                        widget.onOpenWorkoutBuilder,
                                    onExportPdf: widget.onExportPdf,
                                  ),
                                ),
                              );
                            },
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    primary.withOpacity(0.35),
                                    primary.withOpacity(0.10),
                                  ],
                                ),
                                border: Border.all(
                                    color: primary.withOpacity(0.6),
                                    width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                a.firstName.characters.first.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: primary,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    a.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      a.accessCode,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primary,
                                      ),
                                    ),
                                  ),
                                ),
                                if (a.injuryTags.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  const Icon(LucideIcons.alertTriangle,
                                      size: 16, color: AppColors.warning),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                isFa
                                    ? 'وزن: ${a.weightKg}kg | هدف: ${bio.targetCalories} کالری (${bio.proteinGrams}g پروتئین)'
                                    : '${a.weightKg}kg | Target: ${bio.targetCalories} kcal (${bio.proteinGrams}g Protein)',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ),
                            trailing: const Icon(LucideIcons.chevronRight,
                                size: 18),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_athletes_list_unique',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AthleteOnboardingSheet(),
          );
        },
        icon: const Icon(LucideIcons.userPlus),
        label: Text(s.tr('new_athlete')),
      ),
    );
  }
}
