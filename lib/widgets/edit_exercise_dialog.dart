import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../l10n/app_localizations.dart';

class EditExerciseDialog extends ConsumerStatefulWidget {
  final Exercise? exercise;

  const EditExerciseDialog({super.key, this.exercise});

  @override
  ConsumerState<EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends ConsumerState<EditExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
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
    _nameController = TextEditingController(text: widget.exercise?.name);
    _descriptionController =
        TextEditingController(text: widget.exercise?.description);
    _selectedMuscleGroup = widget.exercise?.muscleGroup ?? _muscleGroups[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final exercise = Exercise(
        supabaseId: widget.exercise?.supabaseId,
        name: _nameController.text,
        muscleGroup: _selectedMuscleGroup,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        createdAt:
            widget.exercise?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.exercise == null) {
        ref.read(exerciseProvider.notifier).addExercise(exercise);
      } else {
        ref.read(exerciseProvider.notifier).updateExercise(exercise);
      }

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.w,
        right: 16.w,
        top: 16.h,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.exercise == null
                    ? l10n.translate('add_exercise')
                    : l10n.translate('edit_exercise'),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 14.sp,
                ),
                decoration: InputDecoration(
                  labelText: l10n.translate('exercise_name'),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  // ignore: deprecated_member_use
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
                    return l10n.translate('name_required');
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
                  fontSize: 14.sp,
                ),
                decoration: InputDecoration(
                  labelText: l10n.translate('muscle_group'),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  // ignore: deprecated_member_use
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
                          child: Text(group),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMuscleGroup = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return l10n.translate('muscle_group_required');
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
                  fontSize: 14.sp,
                ),
                decoration: InputDecoration(
                  labelText: l10n.translate('description'),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  // ignore: deprecated_member_use
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
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      l10n.translate('save'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
