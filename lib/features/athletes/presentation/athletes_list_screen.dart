import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/local/app_database.dart';
import '../domain/scientific_bio_calculator.dart';
import 'athlete_detail_screen.dart';
import 'athlete_onboarding_sheet.dart';
import 'athletes_provider.dart';

class AthletesListScreen extends ConsumerWidget {
  final void Function(AthleteEntity athlete)? onOpenWorkoutBuilder;
  final void Function(AthleteEntity athlete, FullProgramEntity program)?
      onExportPdf;

  const AthletesListScreen({
    super.key,
    this.onOpenWorkoutBuilder,
    this.onExportPdf,
  });

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
                  Text(isFa
                      ? 'ماشینحساب رکورد ۱ تکرار (1RM)'
                      : '1-Rep Max (1RM) Calculator'),
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
                  Text(
                    '100% (1RM): $result kg',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '85% (6 Reps): ${(result * 0.85).toStringAsFixed(1)} kg  |  '
                    '75% (10 Reps): ${(result * 0.75).toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athletes = ref.watch(filteredAthletesProvider);
    final s = AppStrings.of(context);
    final isFa = s.isFa;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.tr('athletes')} (${athletes.length})'),
        actions: [
          IconButton(
            tooltip: isFa ? 'ماشینحساب 1RM' : '1RM Calculator',
            icon: const Icon(LucideIcons.calculator),
            onPressed: () => _show1RMCalculatorDialog(context, isFa),
          ),
        ],
      ),
      body: Column(
        children: [
          if (athletes.isNotEmpty ||
              ref.watch(athleteSearchQueryProvider).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (v) =>
                    ref.read(athleteSearchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: isFa
                      ? 'جستجوی نام یا شماره موبایل شاگرد...'
                      : 'Search athlete name or phone...',
                  prefixIcon: const Icon(LucideIcons.search),
                ),
              ),
            ),
          Expanded(
            child: athletes.isEmpty
                ? Center(
                    child: Text(isFa
                        ? 'هیچ ورزشکاری یافت نشد. روی دکمه + بزنید.'
                        : 'No athletes found. Tap + to add.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AthleteDetailScreen(
                                  athleteId: a.id,
                                  onOpenWorkoutBuilder: onOpenWorkoutBuilder,
                                  onExportPdf: onExportPdf,
                                ),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primary.withOpacity(0.2),
                            child: Text(
                              a.firstName.characters.first.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (a.injuryTags.isNotEmpty)
                                const Icon(LucideIcons.alertTriangle,
                                    size: 16, color: AppColors.warning),
                            ],
                          ),
                          subtitle: Text(
                            isFa
                                ? 'وزن: ${a.weightKg}kg | هدف: ${bio.targetCalories} کالری (${bio.proteinGrams}g پروتئین)'
                                : '${a.weightKg}kg | Target: ${bio.targetCalories} kcal (${bio.proteinGrams}g Protein)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(LucideIcons.chevronRight,
                              size: 18),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
