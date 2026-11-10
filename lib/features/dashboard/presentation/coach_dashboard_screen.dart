import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/maxgym_brand_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../../core/utils/number_parser.dart';
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
    final primary = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopBento = screenWidth >= 960;

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
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  MaxGymBrandConfig.bundledLogoAsset,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    LucideIcons.dumbbell,
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
                  Text(branding.gymName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(
                    branding.coachName,
                    style: TextStyle(
                        fontSize: 11,
                        color: primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:
                isFa ? 'مرکز دانلود و کنسول سوپر-ادمین' : 'Download & Admin Hub',
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
            tooltip: isFa ? 'همگامسازی ابری با Supabase' : 'Sync with Cloud',
            icon: Icon(LucideIcons.cloudUpload, color: primary),
            onPressed: widget.onTriggerCloudSync,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ۱. گرید ۴ تایی کارتهای سهبعدی با موج نئونی (Sparkline Wave)
          if (isDesktopBento)
            Row(
              children: [
                _stat3DWaveCard(
                  title: isFa ? 'ورزشکاران فعال' : 'Active Athletes',
                  value: '${athletes.length}',
                  subtitle: isFa ? 'پرونده فعال باشگاهی' : 'Active Profiles',
                  icon: LucideIcons.users,
                  color: primary,
                  seed: 1.0,
                ),
                const SizedBox(width: 14),
                _stat3DWaveCard(
                  title: isFa ? 'درآمد دریافتشده' : 'Collected Revenue',
                  value: _hideFinancialFigures
                      ? '••••••'
                      : totalRevenue.toPriceFormat(),
                  subtitle: isFa ? 'تومان (تسویهشده)' : 'Paid Tuition',
                  icon: LucideIcons.wallet,
                  color: AppColors.success,
                  seed: 2.2,
                ),
                const SizedBox(width: 14),
                _stat3DWaveCard(
                  title: isFa ? 'برنامههای رو به اتمام' : 'Expiring Soon',
                  value: '${expiringPrograms.length}',
                  subtitle: isFa ? 'کمتر از ۵ روز اعتبار' : '< 5 Days Left',
                  icon: LucideIcons.clock,
                  color: AppColors.warning,
                  seed: 3.5,
                ),
                const SizedBox(width: 14),
                _stat3DWaveCard(
                  title: isFa ? 'مطالبات / بدهکاران' : 'Pending Debt',
                  value: _hideFinancialFigures
                      ? '••••••'
                      : totalPendingDebt.toPriceFormat(),
                  subtitle: isFa ? 'تومان (در انتظار تسویه)' : 'Unpaid Balance',
                  icon: LucideIcons.alertCircle,
                  color: AppColors.danger,
                  seed: 4.8,
                ),
              ],
            )
          else ...[
            Row(
              children: [
                _stat3DWaveCard(
                  title: isFa ? 'ورزشکاران فعال' : 'Active Athletes',
                  value: '${athletes.length}',
                  subtitle: isFa ? 'پرونده فعال' : 'Profiles',
                  icon: LucideIcons.users,
                  color: primary,
                  seed: 1.0,
                ),
                const SizedBox(width: 12),
                _stat3DWaveCard(
                  title: isFa ? 'درآمد دریافتشده' : 'Collected Revenue',
                  value: _hideFinancialFigures
                      ? '••••••'
                      : totalRevenue.toPriceFormat(),
                  subtitle: isFa ? 'تومان' : 'Paid',
                  icon: LucideIcons.wallet,
                  color: AppColors.success,
                  seed: 2.2,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat3DWaveCard(
                  title: isFa ? 'برنامههای رو به اتمام' : 'Expiring Soon',
                  value: '${expiringPrograms.length}',
                  subtitle: isFa ? 'نیازمند تمدید' : 'Renew Soon',
                  icon: LucideIcons.clock,
                  color: AppColors.warning,
                  seed: 3.5,
                ),
                const SizedBox(width: 12),
                _stat3DWaveCard(
                  title: isFa ? 'مطالبات / بدهکاران' : 'Pending Debt',
                  value: _hideFinancialFigures
                      ? '••••••'
                      : totalPendingDebt.toPriceFormat(),
                  subtitle: isFa ? 'تومان' : 'Unpaid',
                  icon: LucideIcons.alertCircle,
                  color: AppColors.danger,
                  seed: 4.8,
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // ۲. چیدمان بنتو گرید دو ستونه در دسکتاپ (و تک ستونه در موبایل)
          if (isDesktopBento)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildExpiringBentoSection(
                          expiringPrograms, db, s, isFa, primary),
                      const SizedBox(height: 20),
                      _buildUnpaidBentoSection(
                          unpaidPrograms, db, s, isFa, primary),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (leaderboard.isNotEmpty) ...[
                        _buildLeaderboardBentoSection(
                            leaderboard, isFa, primary),
                        const SizedBox(height: 20),
                      ],
                      if (inactiveAthletesAlert.isNotEmpty)
                        _buildSmartInsightsBentoSection(
                            inactiveAthletesAlert, isFa, primary),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            if (leaderboard.isNotEmpty) ...[
              _buildLeaderboardBentoSection(leaderboard, isFa, primary),
              const SizedBox(height: 18),
            ],
            if (inactiveAthletesAlert.isNotEmpty) ...[
              _buildSmartInsightsBentoSection(
                  inactiveAthletesAlert, isFa, primary),
              const SizedBox(height: 18),
            ],
            _buildExpiringBentoSection(expiringPrograms, db, s, isFa, primary),
            const SizedBox(height: 18),
            _buildUnpaidBentoSection(unpaidPrograms, db, s, isFa, primary),
          ],

          const SizedBox(height: 90),
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

  Widget _buildLeaderboardBentoSection(
      List<Map<String, dynamic>> leaderboard, bool isFa, Color primary) {
    return MaxGymGlassCard(
      accentColor: const Color(0xFFFFD700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trophy,
                  color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFa
                      ? 'لیدربرد منظمترین قهرمانان باشگاه MAX GYM'
                      : 'MAX GYM Champions Leaderboard',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(
            leaderboard.take(3).length,
            (idx) {
              final entry = leaderboard[idx];
              final ath = entry['athlete'] as AthleteEntity;
              final medals = ['🥇', '🥈', '🥉'];
              final medalColors = [
                const Color(0xFFFFD700),
                const Color(0xFFC0C0C0),
                const Color(0xFFCD7F32),
              ];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: medalColors[idx].withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: medalColors[idx].withOpacity(0.35), width: 1.2),
                ),
                child: ListTile(
                  dense: true,
                  leading: Text(medals[idx],
                      style: const TextStyle(fontSize: 24)),
                  title: Text(ath.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(isFa
                      ? '${entry['sessions']} جلسه ثبتشده • ${entry['water']} لیوان آبرسانی'
                      : '${entry['sessions']} Sessions • ${entry['water']} Glasses Water'),
                  trailing: Chip(
                    backgroundColor: medalColors[idx].withOpacity(0.22),
                    label: Text(
                      '${entry['score']} PTS',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: medalColors[idx],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsightsBentoSection(
      List<AthleteEntity> inactiveAthletesAlert, bool isFa, Color primary) {
    return MaxGymGlassCard(
      accentColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, color: primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFa
                      ? 'هوش تجاری مربی (نیازمند پیگیری تمرین):'
                      : 'Smart Trainer Insights (Follow-up Needed):',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.activity,
                  color: Colors.orangeAccent),
            ),
            title: Text(
              isFa
                  ? '${inactiveAthletesAlert.length} ورزشکار بیش از ۴ روز است گزارش تمرین ثبت نکردهاند'
                  : '${inactiveAthletesAlert.length} athletes haven\'t logged workouts in 4+ days',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                inactiveAthletesAlert
                    .take(4)
                    .map((a) => a.fullName)
                    .join(' ، '),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringBentoSection(List<FullProgramEntity> expiringPrograms,
      LocalAppDatabase db, AppStrings s, bool isFa, Color primary) {
    return MaxGymGlassCard(
      accentColor:
          expiringPrograms.isEmpty ? AppColors.success : AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                s.tr('expiring_programs'),
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (expiringPrograms.isEmpty)
            Text(
              isFa
                  ? '✅ تمام برنامههای ورزشکاران دارای اعتبار زمانی کافی هستند.'
                  : '✅ All athlete programs are up to date.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            )
          else
            ...expiringPrograms.map((p) {
              final athlete = db.getAthleteById(p.athleteId);
              if (athlete == null) return const SizedBox.shrink();
              final daysLeft = p.remainingDays;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
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
        ],
      ),
    );
  }

  Widget _buildUnpaidBentoSection(List<FullProgramEntity> unpaidPrograms,
      LocalAppDatabase db, AppStrings s, bool isFa, Color primary) {
    return MaxGymGlassCard(
      accentColor:
          unpaidPrograms.isEmpty ? AppColors.success : AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wallet, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                s.tr('unpaid_invoices'),
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (unpaidPrograms.isEmpty)
            Text(
              isFa
                  ? '✅ هیچ ورزشکار بدهکاری ثبت نشده است.'
                  : '✅ No unpaid invoices.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            )
          else
            ...unpaidPrograms.map((p) {
              final athlete = db.getAthleteById(p.athleteId);
              if (athlete == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
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
                  subtitle: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _hideFinancialFigures
                          ? '••••••'
                          : '${p.remainingDebt.toPriceFormat()} T',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w900,
                      ),
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
        ],
      ),
    );
  }

  Widget _stat3DWaveCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double seed,
  }) {
    return Expanded(
      child: MaxGym3DTiltCard(
        glowColor: color,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 138,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.24),
                  const Color(0xFF141B17),
                  const Color(0xFF0E1310),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.45), width: 1.5),
            ),
            child: Stack(
              children: [
                // موج نئونی پسزمینه کارت (Sparkline Wave)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SparklineWavePainter(color: color, seed: seed),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklineWavePainter extends CustomPainter {
  final Color color;
  final double seed;

  _SparklineWavePainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final fillPath = Path();
    final baseLine = size.height * 0.78;

    path.moveTo(0, baseLine);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, baseLine);

    for (double x = 0; x <= size.width; x += 8) {
      final y = baseLine +
          math.sin((x / size.width * math.pi * 2.2) + seed) * 12 +
          math.cos((x / size.width * math.pi * 1.1) - seed) * 6;
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklineWavePainter oldDelegate) => false;
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isFa ? 'بانک قالبهای آماده (Smart Templates)' : 'Smart Templates'),
      ),
      body: templates.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: MaxGymGlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.copyCheck,
                            size: 46, color: primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isFa
                            ? 'بانک قالبهای هوشمند شما خالی است'
                            : 'No Smart Templates Yet',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFa
                            ? 'هنگام طراحی برنامه برای هر شاگرد، گزینه «ذخیره به عنوان قالب آماده» را فعال کنید تا اینجا نمایش داده شود.'
                            : 'Save any program as a template to reuse it in 1 tap.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: templates.length,
              itemBuilder: (ctx, i) {
                final t = templates[i];
                final activeDaysCount =
                    t.days.where((d) => !d.isRestDay).length;
                return MaxGymGlassCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primary.withOpacity(0.2),
                      child: Icon(LucideIcons.copyCheck, color: primary),
                    ),
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
