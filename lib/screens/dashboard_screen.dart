import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:max_gym/widgets/avatar_widget.dart';
import 'package:vibration/vibration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/athlete.dart';
import '../providers/athlete_provider.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/stats_card.dart';
import '../widgets/quick_actions.dart';
import '../l10n/app_localizations.dart';
import 'athlete_profile_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _filterGender;
  String? _filterStatus;
  String _sortBy = 'name';
  final List<String> _genders = ['male', 'female'];
  final List<String> _statuses = ['active', 'inactive'];
  int _selectedIndex = 0;
  late AnimationController _animationController;
  bool _isSearchOpen = false;
  bool _isFilterOpen = false;
  List<Athlete> _displayedAthletes = [];
  final int _pageSize = 10;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.forward();
    _loadInitialAthletes();
    _scrollController.addListener(_onScroll);
  }

  void _loadInitialAthletes() {
    final athletes = ref.read(athleteProvider);
    setState(() {
      _displayedAthletes = athletes.take(_pageSize).toList();
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
    await Future.delayed(const Duration(milliseconds: 500));
    final allAthletes = ref.read(athleteProvider);
    final newAthletes =
        allAthletes.skip(_displayedAthletes.length).take(_pageSize).toList();
    setState(() {
      _displayedAthletes.addAll(newAthletes);
      _isLoadingMore = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
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
    }
  }

  Future<void> _deleteAthlete(String supabaseId) async {
    final l10n = AppLocalizations.of(context)!;
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
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('athlete_deleted')),
            action: SnackBarAction(
              label: l10n.translate('undo'),
              onPressed: () => _addAthleteBack(supabaseId),
            ),
          ),
        );
      } catch (e) {
        await ref.read(firebaseServiceProvider).logError(e.toString());
      }
    }
  }

  Future<void> _addAthleteBack(String supabaseId) async {
    // Logic to restore athlete (implement based on your needs)
  }

  Future<void> _showEditDialog(Athlete athlete) async {
    // ignore: unused_local_variable
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditAthleteDialog(athlete: athlete),
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
        ..createdAt = DateTime.now().toIso8601String();
      final supabaseId =
          await ref.read(supabaseServiceProvider).addAthlete(newAthlete);
      await ref.read(isarServiceProvider).addAthlete(newAthlete, supabaseId);
      ref
          .read(athleteProvider.notifier)
          .addAthlete(newAthlete..supabaseId = supabaseId);
      await ref
          .read(firebaseServiceProvider)
          .logEvent(name: 'athlete_duplicated', parameters: {'name': newName});
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('athlete_duplicated'))),
      );
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  Widget _buildStatsSection(List<Athlete> athletes) {
    final l10n = AppLocalizations.of(context)!;
    final totalAthletes = athletes.length;
    final activeAthletes = athletes
        .where((a) => ref
            .read(workoutPlanProvider(a.supabaseId ?? ''))
            .any((p) => p.status == 'active'))
        .length;
    final inactiveAthletes = totalAthletes - activeAthletes;
    final todayAthletes = athletes
        .where((a) =>
            DateTime.parse(a.createdAt ?? '').toLocal().day ==
            DateTime.now().day)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
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
              const SizedBox(width: 8),
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

  Widget _buildSearchOverlay() {
    final l10n = AppLocalizations.of(context)!;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        // ignore: deprecated_member_use
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  label: l10n.translate('search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isSearchOpen = false),
                  child: Text(l10n.translate('close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOverlay() {
    final l10n = AppLocalizations.of(context)!;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        // ignore: deprecated_member_use
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  hint: Text(l10n.translate('filter_gender')),
                  value: _filterGender,
                  isExpanded: true,
                  items: _genders
                      .map((gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterGender = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  hint: Text(l10n.translate('filter_status')),
                  value: _filterStatus,
                  isExpanded: true,
                  items: _statuses
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(l10n.translate(status)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  hint: Text(l10n.translate('sort_by')),
                  value: _sortBy,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'name',
                      child: Text(l10n.translate('name')),
                    ),
                    DropdownMenuItem(
                      value: 'weight',
                      child: Text(l10n.translate('weight')),
                    ),
                    DropdownMenuItem(
                      value: 'date',
                      child: Text(l10n.translate('date_added')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value ?? 'name';
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isFilterOpen = false),
                  child: Text(l10n.translate('close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAthletesTab(BuildContext context, List<Athlete> athletes) {
    final l10n = AppLocalizations.of(context)!;
    final filteredAthletes = _displayedAthletes.where((athlete) {
      final matchesSearch = athlete.name
              ?.toLowerCase()
              .contains(_searchController.text.toLowerCase()) ??
          true;
      final matchesGender =
          _filterGender == null || athlete.gender == _filterGender;
      final matchesStatus = _filterStatus == null ||
          ref
              .read(workoutPlanProvider(athlete.supabaseId ?? ''))
              .any((p) => p.status == _filterStatus);
      return matchesSearch && matchesGender && matchesStatus;
    }).toList();

    filteredAthletes.sort((a, b) {
      if (_sortBy == 'name') {
        return (a.name ?? '').compareTo(b.name ?? '');
      } else if (_sortBy == 'weight') {
        return (a.weight ?? 0).compareTo(b.weight ?? 0);
      } else {
        return DateTime.parse(a.createdAt ?? '')
            .compareTo(DateTime.parse(b.createdAt ?? ''));
      }
    });

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshData,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Directionality(
                    textDirection: l10n.locale.languageCode == 'fa'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: _buildStatsSection(athletes),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == filteredAthletes.length) {
                      return _isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox.shrink();
                    }
                    final athlete = filteredAthletes[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Dismissible(
                            key: Key(athlete.supabaseId ?? ''),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              color: Colors.blue,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child:
                                  const Icon(Icons.edit, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              if (direction == DismissDirection.endToStart) {
                                _deleteAthlete(athlete.supabaseId ?? '');
                              } else {
                                _showEditDialog(athlete);
                              }
                            },
                            child: GestureDetector(
                              onLongPress: () {
                                Vibration.vibrate(duration: 200);
                                _duplicateAthlete(athlete);
                              },
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AthleteProfileScreen(athlete: athlete),
                                  ),
                                );
                              },
                              onDoubleTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) =>
                                      _buildQuickPlanView(athlete),
                                );
                              },
                              child: CustomCard(
                                child: ListTile(
                                  leading: AvatarWidget(
                                    gender: athlete.gender,
                                    name: athlete.name,
                                  ),
                                  title: Text(
                                    athlete.name ?? 'Unknown',
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              const AlwaysStoppedAnimation<
                                                  Color>(Color(0xFFE53935)),
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
                  childCount: filteredAthletes.length + 1,
                ),
              ),
            ],
          ),
        ),
        if (_isSearchOpen) _buildSearchOverlay(),
        if (_isFilterOpen) _buildFilterOverlay(),
      ],
    );
  }

  Widget _buildQuickPlanView(Athlete athlete) {
    final plans = ref.watch(workoutPlanProvider(athlete.supabaseId ?? ''));
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('current_plan'),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (plans.isEmpty)
              Text(l10n.translate('no_plans'),
                  style: const TextStyle(color: Colors.white70))
            else
              ...plans.map((plan) => ListTile(
                    title: Text(plan.name ?? 'Workout',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      plan.exercises
                          .map((e) => '${e.name}: ${e.sets} sets')
                          .join(', '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(supabaseServiceProvider).getNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text(l10n.translate('error_loading_notifications')));
        }
        final notifications = snapshot.data ?? [];
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Directionality(
              textDirection: l10n.locale.languageCode == 'fa'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Column(
                children: [
                  CustomCard(
                    title: l10n.translate('notifications'),
                    child: notifications.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(l10n.translate('no_notifications'),
                                style: const TextStyle(color: Colors.white)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              return ListTile(
                                leading: Icon(Icons.notifications,
                                    color: const Color(0xFFE53935)),
                                title: Text(
                                  notification['title'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  notification['body'],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: Text(
                                  notification['created_at'] != null
                                      ? DateTime.parse(
                                              notification['created_at'])
                                          .toLocal()
                                          .toString()
                                          .split('.')[0]
                                      : '',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final athletes = ref.watch(athleteProvider);
    final l10n = AppLocalizations.of(context)!;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.globalPosition.dx < 50 && details.delta.dx > 0) {
            Scaffold.of(context).openDrawer();
          } else if (details.delta.dx.abs() > 2) {
            setState(() {
              _selectedIndex = details.delta.dx > 0 ? 0 : 1;
            });
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE53935), Color(0xFF212121)],
            ),
          ),
          child: _selectedIndex == 0
              ? _buildAthletesTab(context, athletes)
              : _buildNotificationsTab(context),
        ),
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Text(l10n.translate('dashboard'),
                style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Transform.scale(
                scale: 1 + 0.1 * _animationController.value,
                child: const Icon(Icons.fitness_center,
                    size: 24, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearchOpen = true),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => setState(() => _isFilterOpen = true),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF212121),
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user?.userMetadata?['name'] ?? 'Coach',
                    style: const TextStyle(fontFamily: 'Montserrat')),
                accountEmail: Text(user?.email ?? '',
                    style: const TextStyle(color: Colors.white70)),
                currentAccountPicture: const CircleAvatar(
                  backgroundImage: AssetImage('assets/images/max.png'),
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFF212121)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6, color: Colors.white),
                title: Text(l10n.translate('theme'),
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'Montserrat')),
                trailing: Switch(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (value) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                  activeColor: const Color(0xFFE53935),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: Text(l10n.translate('settings'),
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'Montserrat')),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: Text(l10n.translate('logout'),
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'Montserrat')),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: const Color(0xFF212121),
        selectedItemColor: const Color(0xFFE53935),
        unselectedItemColor: Colors.white70,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: l10n.translate('athletes'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.notifications),
            label: l10n.translate('notifications'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => const QuickActions(),
          );
        },
        backgroundColor: const Color(0xFFE53935),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _EditAthleteDialog extends StatefulWidget {
  final Athlete athlete;

  const _EditAthleteDialog({required this.athlete});

  @override
  State<_EditAthleteDialog> createState() => _EditAthleteDialogState();
}

class _EditAthleteDialogState extends State<_EditAthleteDialog> {
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.athlete.name);
    _weightController =
        TextEditingController(text: widget.athlete.weight?.toString());
    _heightController =
        TextEditingController(text: widget.athlete.height?.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.translate('edit')),
      backgroundColor: Theme.of(context).cardColor,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              label: l10n.translate('name'),
              controller: _nameController,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              label: l10n.translate('weight'),
              controller: _weightController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              label: l10n.translate('height'),
              controller: _heightController,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.translate('cancel')),
        ),
        Consumer(
          builder: (context, ref, child) => TextButton(
            onPressed: () async {
              final updatedAthlete = Athlete()
                ..id = widget.athlete.id
                ..supabaseId = widget.athlete.supabaseId
                ..name = _nameController.text
                ..weight = double.tryParse(_weightController.text)
                ..height = double.tryParse(_heightController.text)
                ..createdAt = widget.athlete.createdAt
                ..goalWeight = widget.athlete.goalWeight
                ..gender = widget.athlete.gender;
              try {
                await ref
                    .read(supabaseServiceProvider)
                    .updateAthlete(updatedAthlete);
                await ref
                    .read(isarServiceProvider)
                    .updateAthlete(updatedAthlete);
                ref
                    .read(athleteProvider.notifier)
                    .updateAthlete(updatedAthlete);
                await ref.read(firebaseServiceProvider).logEvent(
                  name: 'athlete_updated',
                  parameters: {'name': updatedAthlete.name ?? ''},
                );
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context, true);
                }
              } catch (e) {
                await ref.read(firebaseServiceProvider).logError(e.toString());
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context, false);
                }
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ),
      ],
    );
  }
}
