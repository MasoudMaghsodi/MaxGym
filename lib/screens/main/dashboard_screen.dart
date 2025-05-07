import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:max_gym/data/models/athlete.dart';
import 'package:max_gym/l10n/app_localizations.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:max_gym/screens/settings_screen.dart';
import 'package:max_gym/widgets/quick_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'athletes_tab.dart';
import 'notifications_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late AnimationController _panelAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final _searchController = TextEditingController();
  String? _filterGender;
  String? _filterStatus;
  String _sortBy = 'name';
  final List<String> _genders = ['male', 'female'];
  final List<String> _statuses = ['active', 'inactive'];
  bool _isSearchOpen = false;
  bool _isFilterOpen = false;
  Timer? _debounceTimer;
  List<Athlete> _filteredAthletes = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _panelAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOut,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filteredAthletes = _applyFiltersAndSort(ref.read(athleteProvider));
      });
    });
  }

  List<Athlete> _applyFiltersAndSort(List<Athlete> athletes) {
    var result = athletes.where((athlete) {
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

    result.sort((a, b) {
      if (_sortBy == 'name') {
        return (a.name ?? '').compareTo(b.name ?? '');
      } else if (_sortBy == 'weight') {
        return (a.weight ?? 0).compareTo(b.weight ?? 0);
      } else {
        return DateTime.parse(a.createdAt ?? '')
            .compareTo(DateTime.parse(b.createdAt ?? ''));
      }
    });

    return result;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _panelAnimationController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _toggleSearchPanel() {
    setState(() {
      if (_isSearchOpen) {
        _panelAnimationController.reverse();
        _isSearchOpen = false;
      } else {
        if (_isFilterOpen) {
          _isFilterOpen = false;
          _panelAnimationController.reverse().then((_) {
            _isSearchOpen = true;
            _panelAnimationController.forward();
          });
        } else {
          _isSearchOpen = true;
          _panelAnimationController.forward();
        }
      }
    });
  }

  void _toggleFilterPanel() {
    setState(() {
      if (_isFilterOpen) {
        _panelAnimationController.reverse();
        _isFilterOpen = false;
      } else {
        if (_isSearchOpen) {
          _isSearchOpen = false;
          _panelAnimationController.reverse().then((_) {
            _isFilterOpen = true;
            _panelAnimationController.forward();
          });
        } else {
          _isFilterOpen = true;
          _panelAnimationController.forward();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final athletes = ref.watch(athleteProvider);
    final l10n = AppLocalizations.of(context)!;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      body: Column(
        children: [
          if (_isSearchOpen || _isFilterOpen)
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _isSearchOpen
                    ? _buildSearchPanel(l10n)
                    : _buildFilterPanel(l10n),
              ),
            ),
          Expanded(
            child: GestureDetector(
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
                    ? AthletesTab(
                        athletes: _filteredAthletes.isEmpty &&
                                (_isSearchOpen || _isFilterOpen)
                            ? _filteredAthletes
                            : athletes,
                      )
                    : const NotificationsTab(),
              ),
            ),
          ),
        ],
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              l10n.translate('dashboard'),
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 20.sp,
              ),
            ),
            SizedBox(width: 8.w),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Transform.scale(
                scale: 1 + 0.1 * _animationController.value,
                child: Icon(
                  Icons.fitness_center,
                  size: 24.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: athletes.isEmpty
            ? []
            : [
                IconButton(
                  icon: Icon(
                    Icons.search,
                    size: 24.sp,
                    color:
                        _isSearchOpen ? const Color(0xFFFF8A80) : Colors.white,
                  ),
                  onPressed: _toggleSearchPanel,
                  tooltip: l10n.translate('search'),
                ),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    size: 24.sp,
                    color:
                        _isFilterOpen ? const Color(0xFFFF8A80) : Colors.white,
                  ),
                  onPressed: _toggleFilterPanel,
                  tooltip: l10n.translate('filter'),
                ),
              ],
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF212121),
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  user?.userMetadata?['name'] ?? 'Coach',
                  style: const TextStyle(fontFamily: 'Montserrat'),
                ),
                accountEmail: Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
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
                title: Text(
                  l10n.translate('theme'),
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Montserrat'),
                ),
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
                title: Text(
                  l10n.translate('settings'),
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Montserrat'),
                ),
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
                title: Text(
                  l10n.translate('logout'),
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Montserrat'),
                ),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
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
      floatingActionButton: athletes.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => const QuickActions(),
                  isScrollControlled: true,
                );
              },
              backgroundColor: const Color(0xFFE53935),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildSearchPanel(AppLocalizations l10n) {
    return Container(
      color: const Color(0xFF212121),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Montserrat',
          fontSize: 14.sp,
        ),
        decoration: InputDecoration(
          hintText: l10n.translate('search'),
          hintStyle: TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontSize: 14.sp,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20.sp),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white70, size: 20.sp),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFFE53935)),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
      ),
    );
  }

  Widget _buildFilterPanel(AppLocalizations l10n) {
    return Container(
      color: const Color(0xFF212121),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._genders.map((gender) => Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Text(
                      l10n.translate(gender),
                      style: TextStyle(
                        color: _filterGender == gender
                            ? Colors.white
                            : Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 12.sp,
                      ),
                    ),
                    selected: _filterGender == gender,
                    selectedColor: const Color(0xFFE53935),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      side: BorderSide(
                        color: _filterGender == gender
                            ? Colors.transparent
                            : Colors.white70,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _filterGender = selected ? gender : null;
                        _filteredAthletes =
                            _applyFiltersAndSort(ref.read(athleteProvider));
                      });
                    },
                  ),
                )),
            ..._statuses.map((status) => Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Text(
                      l10n.translate(status),
                      style: TextStyle(
                        color: _filterStatus == status
                            ? Colors.white
                            : Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 12.sp,
                      ),
                    ),
                    selected: _filterStatus == status,
                    selectedColor: const Color(0xFFE53935),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      side: BorderSide(
                        color: _filterStatus == status
                            ? Colors.transparent
                            : Colors.white70,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _filterStatus = selected ? status : null;
                        _filteredAthletes =
                            _applyFiltersAndSort(ref.read(athleteProvider));
                      });
                    },
                  ),
                )),
            DropdownButton<String>(
              value: _sortBy,
              icon: Icon(Icons.sort, color: Colors.white70, size: 20.sp),
              dropdownColor: const Color(0xFF212121),
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: 'name',
                  child: Text(
                    l10n.translate('name'),
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'weight',
                  child: Text(
                    l10n.translate('weight'),
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'date',
                  child: Text(
                    l10n.translate('date_added'),
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _sortBy = value ?? 'name';
                  _filteredAthletes =
                      _applyFiltersAndSort(ref.read(athleteProvider));
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
