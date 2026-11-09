import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../../data/local/app_database.dart';
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
  bool _isPrivacyMode = false;

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);
    final athletes = ref.watch(athletesProvider);
    final db = ref.watch(appDatabaseProvider);
    final allPrograms = db.getAllPrograms(includeTemplates: false);
    final s = AppStrings.of(context);
    final isFa = s.isFa;
    final theme = Theme.of(context);

    // محاسبه شاخص‌های کلیدی مالی و انقضای برنامه‌ها
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(branding.gymName, style: const TextStyle(fontSize: 16)),
            Text(
              branding.coachName,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isPrivacyMode
                ? (isFa ? 'نمایش مبالغ مالی' : 'Show Financial Amounts')
                : (isFa
                    ? 'حالت حریم خصوصی (مخفی‌سازی درآمد در حضور شاگرد)'
                    : 'Privacy Mode (Hide Amounts)'),
            icon: Icon(
              _isPrivacyMode ? LucideIcons.eyeOff : LucideIcons.eye,
              color: _isPrivacyMode ? AppColors.warning : null,
            ),
            onPressed: () => setState(() => _isPrivacyMode = !_isPrivacyMode),
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
          // ۱. کارت‌های آماری بالای داشبورد
          Row(
            children: [
              _statCard(
                title: isFa ? 'ورزشکاران فعال' : 'Active Athletes',
                value: '${athletes.length}',
                icon: LucideIcons.users,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: isFa ? 'درآمد دریافت‌شده' : 'Collected Revenue',
                value: _isPrivacyMode
                    ? '******'
                    : totalRevenue.toStringAsFixed(0),
                icon: LucideIcons.wallet,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                title: isFa ? 'برنامه‌های رو به اتمام' : 'Expiring Soon',
                value: '${expiringPrograms.length}',
                icon: LucideIcons.clock,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: isFa ? 'مطالبات / بدهکاران' : 'Pending Debt',
                value: _isPrivacyMode
                    ? '******'
                    : totalPendingDebt.toStringAsFixed(0),
                icon: LucideIcons.alertCircle,
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ۲. هشدار برنامه‌های رو به اتمام یا منقضی‌شده
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

          // ۳. لیست بدهکاران مالی
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
                  subtitle: Text(p.title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isPrivacyMode
                            ? '******'
                            : '${p.remainingDebt.toStringAsFixed(0)} T',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          db.settleProgramDebt(p.id);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFa
                                  ? 'بدهی ${athlete.fullName} با موفقیت تسویه شد.'
                                  : 'Debt settled for ${athlete.fullName}'),
                            ),
                          );
                        },
                        child: Text(isFa ? 'تسویه شد' : 'Settle',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 80),
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// صفحه نمایش قالب‌های آماده مربی (Smart Templates Tab)
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isFa
                                ? 'قالب «${t.title}» حذف شد.'
                                : 'Template ${t.title} deleted.'),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
