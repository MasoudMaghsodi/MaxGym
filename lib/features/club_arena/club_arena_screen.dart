import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/number_parser.dart';
import '../../core/widgets/maxgym_3d_widgets.dart';
import '../../data/local/app_database.dart';

class ClubFeedPostModel {
  final String id;
  final String athleteId;
  final String athleteName;
  final String athleteBadge;
  final String workoutTitle;
  final int totalSets;
  final double totalVolumeKg;
  final String prHighlight;
  final int streakDays;
  final int fireCount;
  final int muscleCount;
  final int crownCount;
  final DateTime createdAt;

  const ClubFeedPostModel({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    required this.athleteBadge,
    required this.workoutTitle,
    required this.totalSets,
    required this.totalVolumeKg,
    required this.prHighlight,
    required this.streakDays,
    this.fireCount = 1,
    this.muscleCount = 0,
    this.crownCount = 0,
    required this.createdAt,
  });

  ClubFeedPostModel copyWith({
    int? fireCount,
    int? muscleCount,
    int? crownCount,
  }) {
    return ClubFeedPostModel(
      id: id,
      athleteId: athleteId,
      athleteName: athleteName,
      athleteBadge: athleteBadge,
      workoutTitle: workoutTitle,
      totalSets: totalSets,
      totalVolumeKg: totalVolumeKg,
      prHighlight: prHighlight,
      streakDays: streakDays,
      fireCount: fireCount ?? this.fireCount,
      muscleCount: muscleCount ?? this.muscleCount,
      crownCount: crownCount ?? this.crownCount,
      createdAt: createdAt,
    );
  }

  factory ClubFeedPostModel.fromJson(Map<String, dynamic> json) {
    return ClubFeedPostModel(
      id: json['id']?.toString() ?? const Uuid().v4(),
      athleteId: json['athlete_id']?.toString() ?? '',
      athleteName: json['athlete_name']?.toString() ?? 'قهرمان مکس‌جیم',
      athleteBadge: json['athlete_badge']?.toString() ?? '🎖️ عضو رسمی باشگاه',
      workoutTitle: json['workout_title']?.toString() ?? 'جلسه تمرینی',
      totalSets: (json['total_sets'] as num?)?.toInt() ?? 12,
      totalVolumeKg: (json['total_volume_kg'] as num?)?.toDouble() ?? 0,
      prHighlight: json['pr_highlight']?.toString() ?? '',
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 1,
      fireCount: (json['fire_count'] as num?)?.toInt() ?? 1,
      muscleCount: (json['muscle_count'] as num?)?.toInt() ?? 0,
      crownCount: (json['crown_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
    );
  }
}

class GymCampaignModel {
  final String id;
  final String title;
  final String description;
  final String metricType; // 'sessions', 'volume', 'streak', 'water'
  final int targetValue;
  final String rewardBadge;
  final DateTime endDate;

  const GymCampaignModel({
    required this.id,
    required this.title,
    required this.description,
    required this.metricType,
    required this.targetValue,
    required this.rewardBadge,
    required this.endDate,
  });

  int get remainingDays =>
      endDate.difference(DateTime.now()).inDays.clamp(0, 365);

  factory GymCampaignModel.fromJson(Map<String, dynamic> json) {
    return GymCampaignModel(
      id: json['id']?.toString() ?? const Uuid().v4(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      metricType: json['metric_type']?.toString() ?? 'sessions',
      targetValue: (json['target_value'] as num?)?.toInt() ?? 20,
      rewardBadge: json['reward_badge']?.toString() ?? '🏆 قهرمان کمپین',
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'].toString()).toLocal()
          : DateTime.now().add(const Duration(days: 30)),
    );
  }
}

class MaxGymClubArenaScreen extends ConsumerStatefulWidget {
  final bool isCoachMode;
  final AthleteEntity? currentAthlete;

  const MaxGymClubArenaScreen({
    super.key,
    required this.isCoachMode,
    this.currentAthlete,
  });

  @override
  ConsumerState<MaxGymClubArenaScreen> createState() =>
      _MaxGymClubArenaScreenState();
}

class _MaxGymClubArenaScreenState extends ConsumerState<MaxGymClubArenaScreen> {
  static final List<ClubFeedPostModel> _localFallbackPosts = [];
  static final List<GymCampaignModel> _localFallbackCampaigns = [
    GymCampaignModel(
      id: 'default_camp_1',
      title: 'چالش ۳۰ روز استمرار آهنین MAX GYM 🔥',
      description:
          'هر ورزشکاری که ۲۰ جلسه تمرین کامل و هیدراتاسیون روزانه را در این ماه ثبت کند، نشان طلایی «پادشاه استمرار» را دریافت می‌کند.',
      metricType: 'sessions',
      targetValue: 20,
      rewardBadge: '👑 پادشاه استمرار مکس‌جیم',
      endDate: DateTime.now().add(const Duration(days: 24)),
    ),
  ];

  List<ClubFeedPostModel> _posts = [];
  List<GymCampaignModel> _campaigns = [];
  List<Map<String, dynamic>> _podiumLeaders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArenaData();
  }

  /// محاسبه نشان افتخار هوشمند هر ورزشکار بر اساس سابقه عضویت و استمرار (Veteran & Streak Badges)
  String _computeAthleteHonorBadge(AthleteEntity athlete) {
    final membershipDays =
        DateTime.now().difference(athlete.createdAt).inDays.abs();
    final jCreated = Jalali.fromDateTime(athlete.createdAt);

    if (membershipDays >= 90) {
      return '👑 کهنه‌کار باشگاه (عضو از ${jCreated.year})';
    }
    if (athlete.streakDays >= 14) {
      return '🔥 پادشاه استمرار (${athlete.streakDays} روز متوالی)';
    }
    if (athlete.streakDays >= 5) {
      return '⚡ جنگجوی منظم باشگاه';
    }
    return '🎖️ ورزشکار رسمی MAX GYM';
  }

  Future<void> _loadArenaData() async {
    setState(() => _isLoading = true);
    final db = ref.read(appDatabaseProvider);

    // ساخت لیست اولیه لیدربرد از دیتابیس محلی
    final localAthletes = db.getAllActiveAthletes();
    final List<Map<String, dynamic>> localLeaders = <Map<String, dynamic>>[];
    for (final a in localAthletes) {
      final logs = db.getWorkoutLogsForAthlete(a.id);
      localLeaders.add(<String, dynamic>{
        'id': a.id,
        'full_name': a.fullName,
        'streak_days': a.streakDays,
        'sessions': logs.length,
        'badge': _computeAthleteHonorBadge(a),
        'score': (a.streakDays * 15) + (logs.length * 20),
      });
    }

    if (localLeaders.isEmpty && widget.currentAthlete != null) {
      final a = widget.currentAthlete!;
      localLeaders.add(<String, dynamic>{
        'id': a.id,
        'full_name': a.fullName,
        'streak_days': a.streakDays,
        'sessions': db.getWorkoutLogsForAthlete(a.id).length,
        'badge': _computeAthleteHonorBadge(a),
        'score': a.streakDays * 15,
      });
    }
    localLeaders
        .sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        if (widget.isCoachMode && client.auth.currentUser != null) {
          final uid = client.auth.currentUser!.id;
          final remotePosts = await client
              .from('club_posts')
              .select()
              .eq('coach_id', uid)
              .order('created_at', ascending: false)
              .limit(50);

          final remoteCampaigns = await client
              .from('gym_campaigns')
              .select()
              .eq('coach_id', uid)
              .eq('is_active', true)
              .order('created_at', ascending: false);

          if (mounted) {
            setState(() {
              _posts = remotePosts
                  .map((r) => ClubFeedPostModel.fromJson(r))
                  .toList();
              _campaigns = remoteCampaigns
                  .map((r) => GymCampaignModel.fromJson(r))
                  .toList();
              if (_campaigns.isEmpty) {
                _campaigns = List.from(_localFallbackCampaigns);
              }
              _podiumLeaders = localLeaders;
              _isLoading = false;
            });
            return;
          }
        } else if (widget.currentAthlete != null) {
          final a = widget.currentAthlete!;
          final res = await client.rpc(
            'athlete_fetch_club_arena',
            params: {
              'p_athlete_id': a.id,
              'p_access_code': a.accessCode,
            },
          );
          if (res is Map<String, dynamic> && mounted) {
            final rawPosts = res['posts'] as List<dynamic>? ?? [];
            final rawCamps = res['campaigns'] as List<dynamic>? ?? [];
            setState(() {
              _posts = rawPosts
                  .map((e) =>
                      ClubFeedPostModel.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
              _campaigns = rawCamps
                  .map((e) =>
                      GymCampaignModel.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
              if (_campaigns.isEmpty) {
                _campaigns = List.from(_localFallbackCampaigns);
              }
              _podiumLeaders = localLeaders;
              _isLoading = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _posts = List.from(_localFallbackPosts);
        _campaigns = List.from(_localFallbackCampaigns);
        _podiumLeaders = localLeaders;
        _isLoading = false;
      });
    }
  }

  Future<void> _reactToPost(int index, String reactionType) async {
    HapticFeedback.lightImpact();
    final post = _posts[index];
    setState(() {
      if (reactionType == 'fire') {
        _posts[index] = post.copyWith(fireCount: post.fireCount + 1);
      } else if (reactionType == 'muscle') {
        _posts[index] = post.copyWith(muscleCount: post.muscleCount + 1);
      } else if (reactionType == 'crown') {
        _posts[index] = post.copyWith(crownCount: post.crownCount + 1);
      }
    });

    try {
      await SupabaseConfig.clientOrNull?.rpc(
        'club_react_to_post',
        params: {
          'p_post_id': post.id,
          'p_reaction_type': reactionType,
        },
      );
    } catch (_) {}
  }

  /// مودال اشتراک‌گذاری تمرین و رکورد جدید توسط ورزشکار در اکسپلور باشگاه
  void _showShareWorkoutVictoryModal(bool isFa) {
    final athlete = widget.currentAthlete;
    if (athlete == null) return;

    final db = ref.read(appDatabaseProvider);
    final progs = db.getProgramsForAthlete(athlete.id);
    final logs = db.getWorkoutLogsForAthlete(athlete.id);

    final defaultTitle = progs.isNotEmpty
        ? progs.first.title.toCleanPersian()
        : (isFa ? 'جلسه تمرینی قدرتی مکس‌جیم' : 'MAX GYM Power Session');

    String defaultPr = '';
    double estimatedVolume = 4800;
    if (logs.isNotEmpty && logs.first.exerciseMaxWeights.isNotEmpty) {
      final topEntry = logs.first.exerciseMaxWeights.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      defaultPr = '${topEntry.value.toStringAsFixed(0)} kg';
      estimatedVolume = logs.first.exerciseMaxWeights.values
          .fold<double>(0, (sum, w) => sum + (w * 36));
    }

    final workoutTitleCtrl = TextEditingController(text: defaultTitle);
    final prCtrl = TextEditingController(
      text: defaultPr.isNotEmpty ? 'رکورد جدید: $defaultPr 🔥' : 'اجرای کامل تمام ست‌ها با فرم عالی 💪',
    );
    final setsCtrl = TextEditingController(text: '16');
    final volumeCtrl =
        TextEditingController(text: estimatedVolume.round().toString());
    final badge = _computeAthleteHonorBadge(athlete);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 22,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.flame,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isFa
                          ? 'اشتراک‌گذاری پیروزی امروز در اکسپلور باشگاه 🏆'
                          : 'Share Workout Victory to Club Arena 🏆',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'نشان افتخار شما: $badge',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: workoutTitleCtrl,
                decoration: InputDecoration(
                  labelText:
                      isFa ? 'عنوان جلسه تمرینی امروز' : 'Workout Session Title',
                  prefixIcon: const Icon(LucideIcons.dumbbell),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: setsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isFa ? 'مجموع ست‌ها' : 'Total Sets',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: volumeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isFa
                              ? 'تناژ کل جابجاشده (kg)'
                              : 'Total Volume (kg)',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prCtrl,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'برجسته‌ترین رکورد یا حس امروزت (PR Highlight)'
                      : 'PR Highlight / Note',
                  prefixIcon: const Icon(LucideIcons.trophy),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  final newPost = ClubFeedPostModel(
                    id: const Uuid().v4(),
                    athleteId: athlete.id,
                    athleteName: athlete.fullName,
                    athleteBadge: badge,
                    workoutTitle: workoutTitleCtrl.text.trim(),
                    totalSets: setsCtrl.text.toSafeInt() ?? 15,
                    totalVolumeKg: volumeCtrl.text.toSafeDouble() ?? 4500,
                    prHighlight: prCtrl.text.trim(),
                    streakDays: athlete.streakDays,
                    createdAt: DateTime.now(),
                  );

                  _localFallbackPosts.insert(0, newPost);
                  setState(() => _posts.insert(0, newPost));

                  try {
                    await SupabaseConfig.clientOrNull?.rpc(
                      'athlete_publish_club_post',
                      params: {
                        'p_athlete_id': athlete.id,
                        'p_access_code': athlete.accessCode,
                        'p_athlete_badge': newPost.athleteBadge,
                        'p_workout_title': newPost.workoutTitle,
                        'p_total_sets': newPost.totalSets,
                        'p_total_volume_kg': newPost.totalVolumeKg,
                        'p_pr_highlight': newPost.prHighlight,
                      },
                    );
                  } catch (_) {}

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(LucideIcons.send),
                label: Text(isFa
                    ? 'انتشار در تالار افتخارات باشگاه ⚡'
                    : 'Publish to Club Feed ⚡'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// مودال ساخت کمپین و چالش جدید توسط مربی
  void _showCreateCampaignModalForCoach(bool isFa) {
    final titleCtrl = TextEditingController(
      text: isFa ? 'چالش ۳۰ روز عضله‌سازی و نظم آهنین' : '30-Day Iron Discipline',
    );
    final descCtrl = TextEditingController(
      text: isFa
          ? 'ثبت حداقل ۲۰ جلسه تمرینی کامل در ماه جاری برای کسب نشان قهرمان کمپین'
          : 'Complete 20 workout sessions this month to earn the Champion Badge.',
    );
    final targetCtrl = TextEditingController(text: '20');
    final badgeCtrl =
        TextEditingController(text: '🏆 قهرمان کمپین ماه مکس‌جیم');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 22,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isFa
                    ? '👑 راه‌اندازی کمپین و رقابت جدید در باشگاه'
                    : '👑 Launch New Gym Campaign',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: isFa ? 'عنوان کمپین *' : 'Campaign Title *',
                  prefixIcon: const Icon(LucideIcons.flag),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'قوانین و توضیحات چالش'
                      : 'Challenge Rules & Description',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              isFa ? 'هدف (تعداد جلسه)' : 'Target Sessions',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: badgeCtrl,
                      decoration: InputDecoration(
                        labelText: isFa ? 'نشان جایزه قهرمان' : 'Reward Badge',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final camp = GymCampaignModel(
                    id: const Uuid().v4(),
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    metricType: 'sessions',
                    targetValue: targetCtrl.text.toSafeInt() ?? 20,
                    rewardBadge: badgeCtrl.text.trim(),
                    endDate: DateTime.now().add(const Duration(days: 30)),
                  );

                  _localFallbackCampaigns.insert(0, camp);
                  setState(() => _campaigns.insert(0, camp));

                  try {
                    final client = SupabaseConfig.clientOrNull;
                    final uid = client?.auth.currentUser?.id;
                    if (client != null && uid != null) {
                      await client.from('gym_campaigns').insert({
                        'id': camp.id,
                        'coach_id': uid,
                        'title': camp.title,
                        'description': camp.description,
                        'metric_type': camp.metricType,
                        'target_value': camp.targetValue,
                        'reward_badge': camp.rewardBadge,
                        'end_date': camp.endDate.toUtc().toIso8601String(),
                        'is_active': true,
                      });
                    }
                  } catch (_) {}

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(LucideIcons.zap),
                label: Text(
                    isFa ? 'فعال‌سازی کمپین برای کل باشگاه' : 'Launch Campaign'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(LucideIcons.trophy, color: primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isFa
                    ? 'کلاب، کمپین‌ها و اکسپلور باشگاه (Arena)'
                    : 'MAX GYM Club Arena & Campaigns',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isCoachMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateCampaignModalForCoach(isFa),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(isFa ? 'کمپین جدید' : 'New Campaign'),
              ),
            )
          else
            IconButton(
              tooltip: isFa ? 'بروزرسانی فید باشگاه' : 'Refresh Arena',
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              onPressed: _loadArenaData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              children: [
                // ۱. سکوی قهرمانی سه‌بعدی باشگاه (3D Champions Podium)
                if (_podiumLeaders.isNotEmpty) ...[
                  _build3DPodiumCard(isFa, primary),
                  const SizedBox(height: 18),
                ],

                // ۲. کمپین‌ها و چالش‌های فعال ماهانه
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFa
                          ? '🔥 کمپین‌ها و رقابت‌های فعال باشگاه'
                          : '🔥 Active Gym Campaigns',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    Text(
                      '${_campaigns.length} Active',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._campaigns.map((camp) {
                  return MaxGymGlassCard(
                    margin: const EdgeInsets.only(bottom: 14),
                    isHighlighted: true,
                    accentColor: const Color(0xFFFF8A00),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                camp.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFFF8A00).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isFa
                                    ? '${camp.remainingDays} روز فرصت'
                                    : '${camp.remainingDays}d Left',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFF8A00),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          camp.description,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: primary.withOpacity(0.16),
                              label: Text(
                                camp.rewardBadge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: primary,
                                ),
                              ),
                            ),
                            Text(
                              isFa
                                  ? 'هدف: ${camp.targetValue} جلسه تمرین'
                                  : 'Target: ${camp.targetValue} Sessions',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white60),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                // ۳. فید زنده اکسپلور باشگاه (Live Gym Pulse & Workout Shares)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFa
                          ? '⚡ نبض زنده باشگاه (آخرین رکوردهای ثبت‌شده)'
                          : '⚡ Live Gym Pulse (Recent Athlete PRs)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    if (!widget.isCoachMode)
                      TextButton.icon(
                        onPressed: () => _showShareWorkoutVictoryModal(isFa),
                        icon: const Icon(LucideIcons.share2, size: 15),
                        label: Text(
                            isFa ? 'ثبت رکورد من +' : '+ Share My Workout'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_posts.isEmpty)
                  MaxGymGlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(LucideIcons.flame,
                            size: 46, color: primary.withOpacity(0.6)),
                        const SizedBox(height: 12),
                        Text(
                          isFa
                              ? 'اولین نفری باش که امروز تمرین و رکوردش رو در تالار باشگاه ثبت می‌کنه! 🔥'
                              : 'Be the first athlete to share today\'s workout & PR in the Arena! 🔥',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        if (!widget.isCoachMode) ...[
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showShareWorkoutVictoryModal(isFa),
                            icon: const Icon(LucideIcons.trophy, size: 18),
                            label: Text(isFa
                                ? 'اشتراک‌گذاری تمرین امروز من'
                                : 'Share Today\'s Workout'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ...List.generate(_posts.length, (idx) {
                    final post = _posts[idx];
                    return MaxGymGlassCard(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: primary.withOpacity(0.18),
                                child: Text(
                                  post.athleteName.characters.first
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.athleteName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      post.athleteBadge,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '🔥 ${post.streakDays}d Streak',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF8A00),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161C19),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🏋️‍♂️ ${post.workoutTitle}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      isFa
                                          ? 'مجموع ست‌ها: ${post.totalSets} ست'
                                          : 'Sets: ${post.totalSets}',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.white70),
                                    ),
                                    const SizedBox(width: 16),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        'Volume: ${post.totalVolumeKg.toPriceFormat()} kg',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (post.prHighlight.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '⚡ ${post.prHighlight}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFB800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // دکمه‌های واکنش ورزشی (🔥 دمت گرم / 💪 ماشاالله / 👑 قهرمان)
                          Row(
                            children: [
                              _reactionPillButton(
                                emoji: '🔥',
                                count: post.fireCount,
                                activeColor: const Color(0xFFFF5E3A),
                                onTap: () => _reactToPost(idx, 'fire'),
                              ),
                              const SizedBox(width: 8),
                              _reactionPillButton(
                                emoji: '💪',
                                count: post.muscleCount,
                                activeColor: primary,
                                onTap: () => _reactToPost(idx, 'muscle'),
                              ),
                              const SizedBox(width: 8),
                              _reactionPillButton(
                                emoji: '👑',
                                count: post.crownCount,
                                activeColor: const Color(0xFFFFD700),
                                onTap: () => _reactToPost(idx, 'crown'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
      floatingActionButton: !widget.isCoachMode
          ? Padding(
              padding: const EdgeInsets.only(bottom: 78),
              child: FloatingActionButton.extended(
                heroTag: 'fab_club_arena_share',
                onPressed: () => _showShareWorkoutVictoryModal(isFa),
                icon: const Icon(LucideIcons.flame),
                label: Text(isFa
                    ? 'اشتراک‌گذاری تمرین امروز در کلاب'
                    : 'Share Workout'),
              ),
            )
          : null,
    );
  }

  Widget _build3DPodiumCard(bool isFa, Color primary) {
    final first = _podiumLeaders.isNotEmpty ? _podiumLeaders[0] : null;
    final second = _podiumLeaders.length > 1 ? _podiumLeaders[1] : null;
    final third = _podiumLeaders.length > 2 ? _podiumLeaders[2] : null;

    Widget podiumColumn({
      required Map<String, dynamic>? leader,
      required String medal,
      required double pillarHeight,
      required Color color,
    }) {
      if (leader == null) return const Expanded(child: SizedBox());
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(medal, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              leader['full_name'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${leader['streak_days']}d 🔥',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: pillarHeight,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.42),
                    color.withOpacity(0.10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: color.withOpacity(0.65), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '${leader['score']} PTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return MaxGymGlassCard(
      accentColor: const Color(0xFFFFD700),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.crown, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              Text(
                isFa
                    ? 'سکوی قهرمانان و کهنه‌کاران باشگاه MAX GYM'
                    : 'MAX GYM 3D Champions Podium',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                podiumColumn(
                  leader: second,
                  medal: '🥈',
                  pillarHeight: 72,
                  color: const Color(0xFFC0C0C0),
                ),
                podiumColumn(
                  leader: first,
                  medal: '🥇',
                  pillarHeight: 98,
                  color: const Color(0xFFFFD700),
                ),
                podiumColumn(
                  leader: third,
                  medal: '🥉',
                  pillarHeight: 56,
                  color: const Color(0xFFCD7F32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionPillButton({
    required String emoji,
    required int count,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activeColor.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
