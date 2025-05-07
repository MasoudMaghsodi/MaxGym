import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lottie/lottie.dart';
import 'package:max_gym/data/models/athlete.dart';
import 'package:max_gym/l10n/app_localizations.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:max_gym/widgets/avatar_widget.dart';
import 'package:max_gym/widgets/custom_card.dart';
import 'package:max_gym/widgets/quick_actions.dart';
import 'package:max_gym/widgets/stats_card.dart';
import 'package:vibration/vibration.dart';
import 'athlete_profile_screen.dart';
import 'edit_athlete_dialog.dart';

class AthletesTab extends ConsumerStatefulWidget {
  final List<Athlete> athletes;

  const AthletesTab({super.key, required this.athletes});

  @override
  ConsumerState<AthletesTab> createState() => AthletesTabState();
}

class AthletesTabState extends ConsumerState<AthletesTab> {
  final _scrollController = ScrollController();
  final int _pageSize = 10;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  Timer? _longPressTimer;
  List<Athlete> _displayedAthletes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialAthletes();
    _scrollController.addListener(_onScroll);
    ref.read(supabaseServiceProvider).subscribeToAthletes(_loadInitialAthletes);
  }

  void _loadInitialAthletes() {
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _displayedAthletes = widget.athletes.take(_pageSize).toList();
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMoreAthletes();
    }
  }

  void _loadMoreAthletes() async {
    setState(() {
      _isLoadingMore = true;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    final newAthletes = widget.athletes
        .skip(_displayedAthletes.length)
        .take(_pageSize)
        .toList();
    if (mounted) {
      setState(() {
        _displayedAthletes.addAll(newAthletes);
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    try {
      await ref.read(supabaseServiceProvider).syncAthletes();
      _loadInitialAthletes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.translate('data_updated')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.translate('refresh_error')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _deleteAthlete(String supabaseId) async {
    final l10n = AppLocalizations.of(context)!;
    final athleteToDelete = _displayedAthletes.firstWhere(
      (athlete) => athlete.supabaseId == supabaseId,
      orElse: () => Athlete(),
    );
    setState(() {
      _displayedAthletes
          .removeWhere((athlete) => athlete.supabaseId == supabaseId);
    });
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_athlete')),
        content: Text(l10n.translate('confirm_delete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(supabaseServiceProvider).deleteAthlete(supabaseId);
        await ref.read(isarServiceProvider).deleteAthlete(supabaseId);
        ref.read(athleteProvider.notifier).deleteAthlete(supabaseId);
        await ref.read(firebaseServiceProvider).logEvent(
            name: 'athlete_deleted', parameters: {'supabaseId': supabaseId});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('athlete_deleted')),
              action: SnackBarAction(
                label: l10n.translate('undo'),
                onPressed: () => _addAthleteBack(athleteToDelete),
              ),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _displayedAthletes.add(athleteToDelete);
        });
        await ref.read(firebaseServiceProvider).logError(e.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('delete_error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      setState(() {
        _displayedAthletes.add(athleteToDelete);
      });
    }
  }

  Future<void> _addAthleteBack(Athlete athlete) async {
    try {
      final supabaseId =
          await ref.read(supabaseServiceProvider).addAthlete(athlete);
      await ref.read(isarServiceProvider).addAthlete(athlete, supabaseId);
      ref
          .read(athleteProvider.notifier)
          .addAthlete(athlete..supabaseId = supabaseId);
      setState(() {
        _displayedAthletes.add(athlete);
      });
      await ref.read(firebaseServiceProvider).logEvent(
          name: 'athlete_restored', parameters: {'supabaseId': supabaseId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.translate('athlete_restored')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.translate('restore_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(Athlete athlete) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditAthleteDialog(athlete: athlete),
    );
    if (result == true) {
      _loadInitialAthletes();
    }
  }

  Future<void> _duplicateAthlete(Athlete athlete) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final newName =
          "${athlete.name ?? 'Athlete'} ${DateTime.now().millisecondsSinceEpoch % 1000}";
      final newAthlete = Athlete()
        ..name = newName
        ..age = athlete.age
        ..weight = athlete.weight
        ..height = athlete.height
        ..bodyFat = athlete.bodyFat
        ..gender = athlete.gender
        ..goalWeight = athlete.goalWeight
        ..createdAt = DateTime.now().toIso8601String()
        ..weightHistory = athlete.weightHistory
        ..measurements = athlete.measurements;
      final supabaseId =
          await ref.read(supabaseServiceProvider).addAthlete(newAthlete);
      await ref.read(isarServiceProvider).addAthlete(newAthlete, supabaseId);
      ref
          .read(athleteProvider.notifier)
          .addAthlete(newAthlete..supabaseId = supabaseId);
      setState(() {
        _displayedAthletes.add(newAthlete);
      });
      await ref
          .read(firebaseServiceProvider)
          .logEvent(name: 'athlete_duplicated', parameters: {'name': newName});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('athlete_duplicated'))),
        );
      }
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('duplicate_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatsSection() {
    final l10n = AppLocalizations.of(context)!;
    final totalAthletes = widget.athletes.length;
    final activeAthletes = widget.athletes
        .where((a) => ref
            .read(workoutPlanProvider(a.supabaseId ?? ''))
            .any((p) => p.status == 'active'))
        .length;
    final inactiveAthletes = totalAthletes - activeAthletes;
    final todayAthletes = widget.athletes
        .where((a) =>
            DateTime.parse(a.createdAt ?? '').toLocal().day ==
            DateTime.now().day)
        .length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: StatsCard(
                  title: l10n.translate('total_athletes'),
                  value: totalAthletes.toString(),
                  icon: Icons.people,
                  color: const Color(0xFFE53935),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: StatsCard(
                  title: l10n.translate('active_athletes'),
                  value: activeAthletes.toString(),
                  icon: Icons.check_circle,
                  color: const Color(0xFF43A047),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: StatsCard(
                  title: l10n.translate('inactive_athletes'),
                  value: inactiveAthletes.toString(),
                  icon: Icons.hourglass_empty,
                  color: const Color(0xFFFBC02D),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: StatsCard(
                  title: l10n.translate('today_added'),
                  value: todayAthletes.toString(),
                  icon: Icons.add_circle,
                  color: const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_state.json',
            width: 200.w,
            height: 200.h,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 16.h),
          Text(
            l10n.translate('empty_dashboard'),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 24.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            l10n.translate('empty_dashboard_subtitle'),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16.sp,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => const QuickActions(),
                isScrollControlled: true,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              l10n.translate('add_athlete'),
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16.sp,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.athletes.isEmpty && !_isRefreshing) {
      return RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.white,
        backgroundColor: const Color(0xFF1976D2),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - kToolbarHeight,
            child: _buildEmptyState(l10n),
          ),
        ),
      );
    }

    final athletesToDisplay = _displayedAthletes;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.white,
      backgroundColor: const Color(0xFF1976D2),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Directionality(
                textDirection: l10n.locale.languageCode == 'fa'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: _buildStatsSection(),
              ),
            ),
          ),
          if (athletesToDisplay.isEmpty && !_isRefreshing)
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height - kToolbarHeight,
                child: _buildEmptyState(l10n),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == athletesToDisplay.length) {
                    return _isLoadingMore
                        ? Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: const Center(
                                child: CircularProgressIndicator(
                              color: Colors.white,
                            )),
                          )
                        : const SizedBox.shrink();
                  }
                  final athlete = athletesToDisplay[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.h,
                      child: FadeInAnimation(
                        child: Dismissible(
                          key: Key(athlete.supabaseId ?? '${athlete.hashCode}'),
                          background: Container(
                            color: Colors.blue,
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: 20.w),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20.w),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              await _deleteAthlete(athlete.supabaseId ?? '');
                              return false;
                            } else {
                              await _showEditDialog(athlete);
                              return false;
                            }
                          },
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AthleteProfileScreen(athlete: athlete),
                                ),
                              );
                            },
                            onLongPressStart: (_) {
                              _longPressTimer = Timer(
                                const Duration(seconds: 3),
                                () {
                                  Vibration.vibrate(duration: 200);
                                  _duplicateAthlete(athlete);
                                },
                              );
                            },
                            onLongPressEnd: (_) {
                              _longPressTimer?.cancel();
                            },
                            child: CustomCard(
                              child: ListTile(
                                leading: AvatarWidget(
                                  gender: athlete.gender,
                                  name: athlete.name,
                                ),
                                title: Text(
                                  athlete.name ?? 'Unknown',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l10n.translate('weight')}: ${athlete.weight ?? '-'} kg, ${l10n.translate('height')}: ${athlete.height ?? '-'} cm',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    if (athlete.goalWeight != null &&
                                        athlete.weight != null)
                                      LinearProgressIndicator(
                                        value: (athlete.weight! -
                                                    athlete.goalWeight!)
                                                .abs() /
                                            athlete.goalWeight!,
                                        backgroundColor: Colors.grey[700],
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Color(0xFFE53935)),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.star_border,
                                      color: Colors.white),
                                  onPressed: () {
                                    // Implement pin athlete
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: athletesToDisplay.length + 1,
              ),
            ),
        ],
      ),
    );
  }
}
