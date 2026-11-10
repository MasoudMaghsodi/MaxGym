import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/maxgym_brand_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../../core/widgets/maxgym_3d_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../admin_and_download/maxgym_hub_and_admin_screen.dart';
import '../../athletes/presentation/athlete_detail_screen.dart';
import '../../athletes/presentation/athlete_onboarding_sheet.dart';
import '../../athletes/presentation/athletes_provider.dart';

class CoachDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onTriggerCloudSync;
  final void Function(AthleteEntity athlete)? onOpenWorkoutBuilder;
  final void Function(AthleteEntity athlete, FullProgramEntity program)?
      onExportPdf;

  const CoachDashboardScreen({
    super.key,
    required this.onTriggerCloudSync,
    this.onOpenWorkoutBuilder,
    this.onExportPdf,
  });

  @override
  ConsumerState<CoachDashboardScreen> createState() =>
      _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends ConsumerState<CoachDashboardScreen> {
  bool _hideFinancialFigures = false;

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);
    final athletes = ref.watch(athletesProvider);
    final db = ref.watch(appDatabaseProvider);
    final allPrograms = db.getAllPrograms(includeTemplates: false);
    final s = AppStrings.of(context);
    final isFa = s.isFa;
    final theme = Theme.of(context);

    double totalRevenue = 0;
    double totalPendingDebt = 0;
    final List<FullProgramEntity> expiringPrograms = [];
    final List<FullProgramEntity> unpaidPrograms = [];

    for (final p in allPrograms) {
      totalRevenue += p.paidAmount;
      if (p.remainingDebt > 0) {
        totalPendingDebt += p.remainingDebt;
        unpaidPrograms.add(p);
      }
      if (p.remainingDays <= 5) {
        expiringPrograms.add(p);
      }
    }

    // محاسبه لیدربرد قهرمانان باشگاه مکس (بر اساس تعداد جلسات تمرین ثبت‌شده و نظم)
    final List<Map<String, dynamic>> leaderboard = [];
    final List<AthleteEntity> inactiveAthletesAlert = [];

    for (final a in athletes) {
      final logs = db.getWorkoutLogsForAthlete(a.id);
      final totalWater =
          logs.fold<int>(0, (sum, item) => sum + item.waterGlasses);
      leaderboard.add({
        'athlete': a,
        'sessions': logs.length,
        'water': totalWater,
        'score': (logs.length * 10) + totalWater,
      });

      if (logs.isEmpty ||
          DateTime.now().difference(logs.first.loggedAt).inDays >= 4) {
        inactiveAthletesAlert.add(a);
      }
    }
    leaderboard.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                MaxGymBrandConfig.bundledLogoAsset,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  LucideIcons.dumbbell,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(branding.gymName, style: const TextStyle(fontSize: 16)),
                  Text(
                    branding.coachName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isFa ? 'مرکز دانلود و کنسول سوپر-ادمین' : 'Download & Admin Hub',
            icon: const Icon(LucideIcons.crown, color: AppColors.warning),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaxGymDownloadAndPwaHubScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: isFa
                ? 'مخفی/نمایش مبالغ مالی در حضور شاگرد'
                : 'Toggle Privacy Mode',
            icon: Icon(
              _hideFinancialFigures ? LucideIcons.eyeOff : LucideIcons.eye,
            ),
            onPressed: () =>
                setState(() => _hideFinancialFigures = !_hideFinancialFigures),
          ),
          IconButton(
            tooltip: isFa ? 'همگام‌سازی ابری با Supabase' : 'Sync with Cloud',
            icon: Icon(LucideIcons.cloudUpload,
                color: theme.colorScheme.primary),
            onPressed: widget.onTriggerCloudSync,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ۱. کارت‌های سه‌بعدی (3D Tilt Cards) آمار کلیدی باشگاه مکس
          Row(
            children: [
              _stat3DCard(
                title: isFa ? 'ورزشکاران فعال' : 'Active Athletes',
                value: '${athletes.length}',
                icon: LucideIcons.users,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _stat3DCard(
                title: isFa ? 'درآمد دریافت‌شده' : 'Collected Revenue',
                value: _hideFinancialFigures
                    ? '••••••'
                    : totalRevenue.toStringAsFixed(0),
                icon: LucideIcons.wallet,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat3DCard(
                title: isFa ? 'برنامه‌های رو به اتمام' : 'Expiring Soon',
                value: '${expiringPrograms.length}',
                icon: LucideIcons.clock,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _stat3DCard(
                title: isFa ? 'مطالبات / بدهکاران' : 'Pending Debt',
                value: _hideFinancialFigures
                    ? '••••••'
                    : totalPendingDebt.toStringAsFixed(0),
                icon: LucideIcons.alertCircle,
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ۲. لیدربرد قهرمانان و منظم‌ترین ورزشکاران باشگاه مکس (Gamification & Leaderboard)
          if (leaderboard.isNotEmpty) ...[
            Row(
              children: [
                const Icon(LucideIcons.trophy,
                    color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: 8),
                Text(
                  isFa
                      ? 'لیدربرد منظم‌ترین قهرمانان باشگاه MAX GYM'
                      : 'MAX GYM Champions Leaderboard',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: List.generate(
                    leaderboard.take(3).length,
                    (idx) {
                      final entry = leaderboard[idx];
                      final ath = entry['athlete'] as AthleteEntity;
                      final medals = ['🥇', '🥈', '🥉'];
                      return ListTile(
                        dense: true,
                        leading: Text(medals[idx],
                            style: const TextStyle(fontSize: 22)),
                        title: Text(ath.fullName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isFa
                            ? '${entry['sessions']} جلسه ثبت‌شده • ${entry['water']} لیوان آبرسانی'
                            : '${entry['sessions']} Sessions • ${entry['water']} Glasses Water'),
                        trailing: Chip(
                          label: Text('${entry['score']} PTS'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ۳. دستیار هوشمند پیگیری شاگردان غیرفعال (Trainer Smart Insights)
          if (inactiveAthletesAlert.isNotEmpty) ...[
            Row(
              children: [
                Icon(LucideIcons.sparkles,
                    color: theme.colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  isFa
                      ? 'هوش تجاری مربی (نیازمند پیگیری تمرین):'
                      : 'Smart Trainer Insights (Follow-up Needed):',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(LucideIcons.activity,
                    color: Colors.orangeAccent),
                title: Text(
                  isFa
                      ? '${inactiveAthletesAlert.length} ورزشکار بیش از ۴ روز است گزارش تمرین ثبت نکرده‌اند'
                      : '${inactiveAthletesAlert.length} athletes haven\'t logged workouts in 4+ days',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  inactiveAthletesAlert
                      .take(4)
                      .map((a) => a.fullName)
                      .join(' ، '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ۴. برنامه‌های رو به اتمام
          Text(
            s.tr('expiring_programs'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (expiringPrograms.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isFa
                      ? '✅ تمام برنامه‌های ورزشکاران دارای اعتبار زمانی کافی هستند.'
                      : '✅ All athlete programs are up to date.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...expiringPrograms.map((p) {
              final athlete = db.getAthleteById(p.athleteId);
              if (athlete == null) return const SizedBox.shrink();
              final daysLeft = p.remainingDays;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x33F59E0B),
                    child: Icon(LucideIcons.bellRing, color: AppColors.warning),
                  ),
                  title: Text(athlete.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    daysLeft <= 0
                        ? (isFa
                            ? 'منقضی شده (${daysLeft.abs()} روز گذشته)'
                            : 'Expired')
                        : (isFa
                            ? '$daysLeft روز تا پایان دوره باقی مانده'
                            : '$daysLeft days remaining'),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      if (widget.onOpenWorkoutBuilder != null) {
                        widget.onOpenWorkoutBuilder!(athlete);
                      }
                    },
                    child: Text(isFa ? 'تمدید برنامه' : 'Renew'),
                  ),
                ),
              );
            }),

          const SizedBox(height: 20),

          // ۵. بدهکاران مالی
          Text(
            s.tr('unpaid_invoices'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (unpaidPrograms.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isFa
                      ? '✅ هیچ ورزشکار بدهکاری ثبت نشده است.'
                      : '✅ No unpaid invoices.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...unpaidPrograms.map((p) {
              final athlete = db.getAthleteById(p.athleteId);
              if (athlete == null) return const SizedBox.shrink();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AthleteDetailScreen(
                          athleteId: athlete.id,
                          onOpenWorkoutBuilder: widget.onOpenWorkoutBuilder,
                          onExportPdf: widget.onExportPdf,
                        ),
                      ),
                    );
                  },
                  leading: const Icon(LucideIcons.badgeDollarSign,
                      color: AppColors.danger),
                  title: Text(athlete.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _hideFinancialFigures
                        ? '••••••'
                        : '${p.remainingDebt.toStringAsFixed(0)} T',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: () {
                      db.settleProgramDebt(p.id);
                      setState(() {});
                    },
                    icon: const Icon(LucideIcons.checkCircle2,
                        size: 16, color: AppColors.success),
                    label: Text(isFa ? 'تسویه شد' : 'Settle'),
                  ),
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_coach_dashboard_unique',
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

  Widget _stat3DCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: MaxGym3DTiltCard(
        glowColor: color,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(height: 4),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final templates = db.getSavedTemplates();
    final isFa = AppStrings.of(context).isFa;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isFa ? 'بانک قالب‌های آماده (Smart Templates)' : 'Smart Templates'),
      ),
      body: templates.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isFa
                      ? 'هنگام طراحی برنامه برای هر شاگرد، گزینه «ذخیره به عنوان قالب آماده» را فعال کنید تا اینجا نمایش داده شود.'
                      : 'Save any program as a template to reuse it in 1 tap.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (ctx, i) {
                final t = templates[i];
                final activeDaysCount =
                    t.days.where((d) => !d.isRestDay).length;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(LucideIcons.copyCheck),
                    title: Text(t.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isFa
                          ? '$activeDaysCount جلسه تمرین در هفته | ${t.dietMeals.length} وعده غذایی | ${t.supplements.length} مکمل'
                          : '$activeDaysCount Workout Days | ${t.dietMeals.length} Meals | ${t.supplements.length} Supplements',
                    ),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.trash2,
                          color: AppColors.danger),
                      onPressed: () {
                        db.deleteProgramOrTemplate(t.id);
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
