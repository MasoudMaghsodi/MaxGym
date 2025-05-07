import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:max_gym/widgets/custom_text_field.dart';
import '../../data/models/athlete.dart';
import '../../providers/athlete_provider.dart';
import '../../l10n/app_localizations.dart';

class QuickActions extends ConsumerStatefulWidget {
  const QuickActions({super.key});

  @override
  ConsumerState<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<QuickActions> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _goalWeightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _waistController = TextEditingController();
  final _armController = TextEditingController();
  String? _gender;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _goalWeightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _armController.dispose();
    super.dispose();
  }

  Future<void> _addAthlete() async {
    if (_formKey.currentState!.validate()) {
      final l10n = AppLocalizations.of(context)!;
      try {
        final now = DateTime.now().toIso8601String();
        final athlete = Athlete()
          ..name = _nameController.text
          ..age = int.tryParse(_ageController.text)
          ..weight = double.tryParse(_weightController.text)
          ..height = double.tryParse(_heightController.text)
          ..goalWeight = double.tryParse(_goalWeightController.text)
          ..bodyFat = double.tryParse(_bodyFatController.text)
          ..gender = _gender
          ..createdAt = now
          ..weightHistory = [
            if (double.tryParse(_weightController.text) != null)
              WeightEntry()
                ..date = now
                ..weight = double.tryParse(_weightController.text)
          ]
          ..measurements = [
            if (double.tryParse(_waistController.text) != null)
              Measurement()
                ..type = 'waist'
                ..value = double.tryParse(_waistController.text)
                ..date = now,
            if (double.tryParse(_armController.text) != null)
              Measurement()
                ..type = 'arm'
                ..value = double.tryParse(_armController.text)
                ..date = now,
          ];

        final supabaseId =
            await ref.read(supabaseServiceProvider).addAthlete(athlete);
        await ref.read(isarServiceProvider).addAthlete(athlete, supabaseId);
        ref
            .read(athleteProvider.notifier)
            .addAthlete(athlete..supabaseId = supabaseId);

        await ref.read(firebaseServiceProvider).logEvent(
            name: 'athlete_added', parameters: {'name': athlete.name ?? ''});

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('athlete_added')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        await ref.read(firebaseServiceProvider).logError(e.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('add_athlete_error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.translate('add_athlete'),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16.h),
              CustomTextField(
                label: l10n.translate('name'),
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.translate('name_required');
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                label: l10n.translate('age'),
                controller: _ageController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final age = int.tryParse(value);
                    if (age == null || age < 0) {
                      return l10n.translate('invalid_age');
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                label: l10n.translate('weight'),
                controller: _weightController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final weight = double.tryParse(value);
                    if (weight == null || weight <= 0) {
                      return l10n.translate('invalid_weight');
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                label: l10n.translate('height'),
                controller: _heightController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final height = double.tryParse(value);
                    if (height == null || height <= 0) {
                      return l10n.translate('invalid_height');
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                label: l10n.translate('goal_weight'),
                controller: _goalWeightController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final goalWeight = double.tryParse(value);
                    if (goalWeight == null || goalWeight <= 0) {
                      return l10n.translate('invalid_goal_weight');
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                label: l10n.translate('body_fat'),
                controller: _bodyFatController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final bodyFat = double.tryParse(value);
                    if (bodyFat == null || bodyFat < 0 || bodyFat > 100) {
                      return l10n.translate('invalid_body_fat');
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: l10n.translate('gender'),
                  labelStyle: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE53935)),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                value: _gender,
                items: ['male', 'female']
                    .map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(l10n.translate(gender)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _gender = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return l10n.translate('gender_required');
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              Text(
                l10n.translate('measurements'),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                label: l10n.translate('waist'),
                controller: _waistController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final waist = double.tryParse(value);
                    if (waist == null || waist <= 0) {
                      return l10n.translate('invalid_waist');
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                label: l10n.translate('arm'),
                controller: _armController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final arm = double.tryParse(value);
                    if (arm == null || arm <= 0) {
                      return l10n.translate('invalid_arm');
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.translate('cancel'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: Colors.white70,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: _addAthlete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: EdgeInsets.symmetric(
                          horizontal: 24.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
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
            ],
          ),
        ),
      ),
    );
  }
}
