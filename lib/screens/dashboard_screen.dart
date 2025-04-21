import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:max_gym/data/models/athlete.dart';
import 'package:max_gym/data/models/workout_plan.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
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
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _genderController = TextEditingController();
  final _heightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<double> _fadeAnimation;
  String? _filterGender;
  final List<String> _genders = ['male', 'female'];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    ref.read(supabaseServiceProvider).syncAthletes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _bodyFatController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _addAthlete() async {
    final athlete = Athlete()
      ..name = _nameController.text
      ..age = int.tryParse(_ageController.text)
      ..weight = double.tryParse(_weightController.text)
      ..createdAt = DateTime.now().toIso8601String()
      ..gender = _genderController.text.isEmpty ? null : _genderController.text
      ..height = double.tryParse(_heightController.text)
      ..bodyFat = double.tryParse(_bodyFatController.text);

    try {
      final supabaseId =
          await ref.read(supabaseServiceProvider).addAthlete(athlete);
      await ref.read(isarServiceProvider).addAthlete(athlete, supabaseId);
      ref
          .read(athleteProvider.notifier)
          .addAthlete(athlete..supabaseId = supabaseId);
      await ref
          .read(firebaseServiceProvider)
          .logAthleteAdded(athlete.name ?? '');
      _nameController.clear();
      _ageController.clear();
      _weightController.clear();
      _genderController.clear();
      _heightController.clear();
      _bodyFatController.clear();
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  Future<void> _deleteAthlete(String supabaseId) async {
    try {
      await ref.read(supabaseServiceProvider).deleteAthlete(supabaseId);
      await ref.read(isarServiceProvider).deleteAthlete(supabaseId);
      ref.read(athleteProvider.notifier).deleteAthlete(supabaseId);
      await ref.read(firebaseServiceProvider).logEvent(
          name: 'athlete_deleted', parameters: {'supabaseId': supabaseId});
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  Future<void> _showEditDialog(Athlete athlete) async {
    final editNameController = TextEditingController(text: athlete.name);
    final editAgeController =
        TextEditingController(text: athlete.age?.toString());
    final editWeightController =
        TextEditingController(text: athlete.weight?.toString());
    final editGenderController = TextEditingController(text: athlete.gender);
    final editHeightController =
        TextEditingController(text: athlete.height?.toString());
    final editBodyFatController =
        TextEditingController(text: athlete.bodyFat?.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('edit')),
        backgroundColor: Theme.of(context).cardColor,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: AppLocalizations.of(context)!.translate('name'),
                controller: editNameController,
              ),
              const SizedBox(height: 8),
              CustomTextField(
                label: AppLocalizations.of(context)!.translate('age'),
                controller: editAgeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CustomTextField(
                label: AppLocalizations.of(context)!.translate('weight'),
                controller: editWeightController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CustomTextField(
                label: AppLocalizations.of(context)!.translate('gender'),
                controller: editGenderController,
              ),
              const SizedBox(height: 8),
              CustomTextField(
                label: AppLocalizations.of(context)!.translate('height'),
                controller: editHeightController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CustomTextField(
                label: AppLocalizations.of(context)!.translate('body_fat'),
                controller: editBodyFatController,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.translate('cancel'),
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color)),
          ),
          CustomButton(
            text: AppLocalizations.of(context)!.translate('save'),
            onPressed: () async {
              final updatedAthlete = Athlete()
                ..id = athlete.id
                ..supabaseId = athlete.supabaseId
                ..name = editNameController.text
                ..age = int.tryParse(editAgeController.text)
                ..weight = double.tryParse(editWeightController.text)
                ..createdAt = athlete.createdAt
                ..goalWeight = athlete.goalWeight
                ..gender = editGenderController.text.isEmpty
                    ? null
                    : editGenderController.text
                ..height = double.tryParse(editHeightController.text)
                ..bodyFat = double.tryParse(editBodyFatController.text);

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
          ),
        ],
      ),
    );

    if (result != true) {
      editNameController.dispose();
      editAgeController.dispose();
      editWeightController.dispose();
      editGenderController.dispose();
      editHeightController.dispose();
      editBodyFatController.dispose();
    }
  }

  Future<void> _showAddWorkoutDialog(String athleteId) async {
    final nameController = TextEditingController();
    final exerciseNameController = TextEditingController();
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final weightController = TextEditingController();
    final endDateController = TextEditingController();
    List<Exercise> exercises = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.translate('add_workout')),
          backgroundColor: Theme.of(context).cardColor,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  label: AppLocalizations.of(context)!.translate('name'),
                  controller: nameController,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  label: AppLocalizations.of(context)!.translate('end_date'),
                  controller: endDateController,
                  keyboardType: TextInputType.datetime,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      endDateController.text = date.toIso8601String();
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.translate('exercises'),
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
                const SizedBox(height: 8),
                CustomTextField(
                  label:
                      AppLocalizations.of(context)!.translate('exercise_name'),
                  controller: exerciseNameController,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  label: AppLocalizations.of(context)!.translate('sets'),
                  controller: setsController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  label: AppLocalizations.of(context)!.translate('reps'),
                  controller: repsController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  label: AppLocalizations.of(context)!.translate('weight'),
                  controller: weightController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: AppLocalizations.of(context)!.translate('add_exercise'),
                  onPressed: () {
                    final exercise = Exercise()
                      ..name = exerciseNameController.text
                      ..sets = int.tryParse(setsController.text)
                      ..reps = int.tryParse(repsController.text)
                      ..weight = double.tryParse(weightController.text);
                    setState(() {
                      exercises.add(exercise);
                    });
                    exerciseNameController.clear();
                    setsController.clear();
                    repsController.clear();
                    weightController.clear();
                  },
                ),
                const SizedBox(height: 8),
                ...exercises.map((e) => ListTile(
                      title: Text(
                          '${e.name}: ${e.sets} sets, ${e.reps} reps, ${e.weight ?? '-'} kg',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color)),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.translate('cancel'),
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color)),
            ),
            CustomButton(
              text: AppLocalizations.of(context)!.translate('save'),
              onPressed: () async {
                final plan = WorkoutPlan()
                  ..name = nameController.text
                  ..exercises = exercises
                  ..athleteId = athleteId
                  ..createdAt = DateTime.now().toIso8601String()
                  ..status = 'active'
                  ..endDate = endDateController.text;
                try {
                  final supabaseId = await ref
                      .read(supabaseServiceProvider)
                      .addWorkoutPlan(plan);
                  await ref
                      .read(isarServiceProvider)
                      .addWorkoutPlan(plan, supabaseId);
                  ref
                      .read(workoutPlanProvider(athleteId).notifier)
                      .addPlan(plan..supabaseId = supabaseId);
                  await ref.read(firebaseServiceProvider).logEvent(
                    name: 'workout_plan_added',
                    parameters: {'name': plan.name ?? ''},
                  );
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  }
                } catch (e) {
                  await ref
                      .read(firebaseServiceProvider)
                      .logError(e.toString());
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _markWorkoutCompleted(
      String supabaseId, String athleteId) async {
    try {
      final plan = await ref
          .read(isarServiceProvider)
          .getWorkoutPlans(athleteId)
          .then((plans) =>
              plans.firstWhere((plan) => plan.supabaseId == supabaseId));
      plan.status = 'completed';
      await ref.read(supabaseServiceProvider).updateWorkoutPlan(plan);
      await ref.read(isarServiceProvider).updateWorkoutPlan(plan);
      ref.read(workoutPlanProvider(athleteId).notifier).updatePlan(plan);
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  Widget _buildAthletesTab(BuildContext context, List<Athlete> athletes) {
    final l10n = AppLocalizations.of(context);
    final filteredAthletes = athletes.where((athlete) {
      final matchesSearch = athlete.name
              ?.toLowerCase()
              .contains(_searchController.text.toLowerCase()) ??
          true;
      final matchesGender =
          _filterGender == null || athlete.gender == _filterGender;
      return matchesSearch && matchesGender;
    }).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Directionality(
          textDirection: l10n!.locale.languageCode == 'fa'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Column(
            children: [
              CustomCard(
                title: l10n.translate('add_athlete'),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CustomTextField(
                        label: l10n.translate('name'),
                        controller: _nameController,
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        label: l10n.translate('age'),
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        label: l10n.translate('weight'),
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        label: l10n.translate('gender'),
                        controller: _genderController,
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        label: l10n.translate('height'),
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        label: l10n.translate('body_fat'),
                        controller: _bodyFatController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      CustomButton(
                        text: l10n.translate('add_athlete'),
                        onPressed: _addAthlete,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomCard(
                title: l10n.translate('search'),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CustomTextField(
                        label: l10n.translate('search'),
                        controller: _searchController,
                        onChanged: (value) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        hint: Text(l10n.translate('filter')),
                        value: _filterGender,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAthletes.length,
                itemBuilder: (context, index) {
                  final athlete = filteredAthletes[index];
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.easeOut,
                    )),
                    child: CustomCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          child: Text(
                            athlete.name?.substring(0, 1).toUpperCase() ?? 'A',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          athlete.name ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          '${l10n.translate('age')}: ${athlete.age ?? '-'}, ${l10n.translate('weight')}: ${athlete.weight ?? '-'} kg, ${l10n.translate('gender')}: ${athlete.gender ?? '-'}',
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodySmall!.color),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.fitness_center,
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                              onPressed: () => _showAddWorkoutDialog(
                                  athlete.supabaseId ?? ''),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                              onPressed: () => _showEditDialog(athlete),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteAthlete(athlete.supabaseId ?? ''),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AthleteProfileScreen(athlete: athlete),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(supabaseServiceProvider).getNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text(l10n!.translate('error_loading_notifications')));
        }
        final notifications = snapshot.data ?? [];
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Directionality(
              textDirection: l10n!.locale.languageCode == 'fa'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Column(
                children: [
                  CustomCard(
                    title: l10n.translate('notifications'),
                    child: notifications.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(l10n.translate('no_notifications')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              return ListTile(
                                leading: Icon(Icons.notifications,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary),
                                title: Text(
                                  notification['title'],
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color),
                                ),
                                subtitle: Text(
                                  notification['body'],
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .color),
                                ),
                                trailing: Text(
                                  notification['created_at'] != null
                                      ? DateTime.parse(
                                              notification['created_at'])
                                          .toLocal()
                                          .toString()
                                          .split('.')[0]
                                      : '',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .color),
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n!.translate('dashboard')),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              // ignore: deprecated_member_use
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: _selectedIndex == 0
            ? _buildAthletesTab(context, athletes)
            : _buildNotificationsTab(context),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
    );
  }
}
