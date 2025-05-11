import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lottie/lottie.dart';
import 'package:max_gym/data/models/exercise.dart';
import 'package:max_gym/l10n/app_localizations.dart';
import 'package:max_gym/providers/exercise_provider.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  final _searchController = TextEditingController();
  // ignore: unused_field
  final List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const EditExerciseDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.translate('exercise_added')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _editExercise(Exercise exercise) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditExerciseDialog(exercise: exercise),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.translate('exercise_updated')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final l10n = AppLocalizations.of(context)!;
    final exerciseToDelete = exercise;
    ref.read(exerciseProvider.notifier).deleteExercise(exercise.supabaseId!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('exercise_deleted')),
          action: SnackBarAction(
            label: l10n.translate('undo'),
            onPressed: () {
              ref.read(exerciseProvider.notifier).addExercise(exerciseToDelete);
            },
          ),
        ),
      );
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_exercise')),
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
    if (confirm != true && mounted) {
      ref.read(exerciseProvider.notifier).addExercise(exerciseToDelete);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('exercise_restored'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exerciseProvider);
    final l10n = AppLocalizations.of(context)!;
    final filteredExercises = exercises
        .where((exercise) =>
            exercise.name
                ?.toLowerCase()
                .contains(_searchController.text.toLowerCase()) ??
            true)
        .toList();

    final groupedExercises = <String, List<Exercise>>{};
    for (var exercise in filteredExercises) {
      final muscleGroup = exercise.muscleGroup ?? 'Other';
      groupedExercises.putIfAbsent(muscleGroup, () => []).add(exercise);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              l10n.translate('exercises'),
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 20.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.fitness_center, size: 24.sp, color: Colors.white),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.search, size: 24.sp, color: Colors.white),
            onPressed: () {
              showSearchPanel(context);
            },
            tooltip: l10n.translate('search'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE53935), Color(0xFF212121)],
          ),
        ),
        child: exercises.isEmpty
            ? _buildEmptyState(l10n)
            : AnimationLimiter(
                child: ListView.builder(
                  itemCount: groupedExercises.length,
                  itemBuilder: (context, index) {
                    final muscleGroup = groupedExercises.keys.elementAt(index);
                    final exercisesInGroup = groupedExercises[muscleGroup]!;
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.h,
                        child: FadeInAnimation(
                          child: ExpansionTile(
                            title: Text(
                              muscleGroup,
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: Colors.white.withOpacity(0.1),
                            collapsedBackgroundColor:
                                Colors.white.withOpacity(0.05),
                            children: exercisesInGroup
                                .asMap()
                                .entries
                                .map((entry) => Dismissible(
                                      key: Key(entry.value.supabaseId!),
                                      background: Container(
                                        color: Colors.blue,
                                        alignment: Alignment.centerLeft,
                                        padding: EdgeInsets.only(left: 20.w),
                                        child: const Icon(Icons.edit,
                                            color: Colors.white),
                                      ),
                                      secondaryBackground: Container(
                                        color: Colors.red,
                                        alignment: Alignment.centerRight,
                                        padding: EdgeInsets.only(right: 20.w),
                                        child: const Icon(Icons.delete,
                                            color: Colors.white),
                                      ),
                                      confirmDismiss: (direction) async {
                                        if (direction ==
                                            DismissDirection.endToStart) {
                                          await _deleteExercise(entry.value);
                                          return false;
                                        } else {
                                          await _editExercise(entry.value);
                                          return false;
                                        }
                                      },
                                      child: ListTile(
                                        title: Text(
                                          entry.value.name ?? 'Unknown',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Montserrat',
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        subtitle: Text(
                                          entry.value.description ?? '',
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        onTap: () => _editExercise(entry.value),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExercise,
        backgroundColor: const Color(0xFFE53935),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void showSearchPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        color: const Color(0xFF212121),
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.translate('search'),
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
          ),
        ),
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
            l10n.translate('empty_exercises'),
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
            l10n.translate('empty_exercises_subtitle'),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16.sp,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _addExercise,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              l10n.translate('add_exercise'),
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
}

class EditExerciseDialog extends ConsumerStatefulWidget {
  final Exercise? exercise;

  const EditExerciseDialog({super.key, this.exercise});

  @override
  ConsumerState<EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends ConsumerState<EditExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedMuscleGroup;
  final List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.exercise != null) {
      _nameController.text = widget.exercise!.name ?? '';
      _descriptionController.text = widget.exercise!.description ?? '';
      _selectedMuscleGroup = widget.exercise!.muscleGroup;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    if (_formKey.currentState!.validate()) {
      final exercise = Exercise(
        supabaseId: widget.exercise?.supabaseId,
        name: _nameController.text,
        muscleGroup: _selectedMuscleGroup,
        description: _descriptionController.text,
        createdAt:
            widget.exercise?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.exercise == null) {
        await ref.read(exerciseProvider.notifier).addExercise(exercise);
      } else {
        await ref.read(exerciseProvider.notifier).updateExercise(exercise);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        color: Color(0xFF212121),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exercise == null
                    ? l10n.translate('add_exercise')
                    : l10n.translate('edit_exercise'),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 16.sp,
                ),
                decoration: InputDecoration(
                  labelText: l10n.translate('name'),
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: l10n.translate('enter_exercise_name'),
                  hintStyle: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontSize: 14.sp,
                  ),
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
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.translate('please_enter_name');
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),
              DropdownButtonFormField<String>(
                value: _selectedMuscleGroup,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 16.sp,
                ),
                decoration: InputDecoration(
                  labelText: l10n.translate('muscle_group'),
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
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
                ),
                items: _muscleGroups
                    .map((group) => DropdownMenuItem(
                          value: group,
                          child: Text(
                            group,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              fontSize: 16.sp,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMuscleGroup = value;
                  });
                },
                dropdownColor: Colors.black54,
                validator: (value) {
                  if (value == null) {
                    return l10n.translate('please_select_muscle_group');
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _descriptionController,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 16.sp,
                ),
                decoration: InputDecoration(
                  labelText: l10n.translate('description'),
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: l10n.translate('enter_description'),
                  hintStyle: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontSize: 14.sp,
                  ),
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
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.translate('cancel'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  ElevatedButton(
                    onPressed: _saveExercise,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: EdgeInsets.symmetric(
                          horizontal: 24.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      l10n.translate('save'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
