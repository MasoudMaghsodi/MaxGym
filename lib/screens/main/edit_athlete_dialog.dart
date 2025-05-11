import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:max_gym/data/models/athlete.dart';
import 'package:max_gym/l10n/app_localizations.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:max_gym/widgets/custom_text_field.dart';

class EditAthleteDialog extends ConsumerStatefulWidget {
  final Athlete athlete;

  const EditAthleteDialog({super.key, required this.athlete});

  @override
  ConsumerState<EditAthleteDialog> createState() => _EditAthleteDialogState();
}

class _EditAthleteDialogState extends ConsumerState<EditAthleteDialog> {
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
            SizedBox(height: 8.h),
            CustomTextField(
              label: l10n.translate('weight'),
              controller: _weightController,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8.h),
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
        TextButton(
          onPressed: () async {
            final updatedAthlete = Athlete()
              ..id = widget.athlete.id
              ..supabaseId = widget.athlete.supabaseId
              ..name = _nameController.text
              ..weight = double.tryParse(_weightController.text)
              ..height = double.tryParse(_heightController.text)
              ..createdAt = widget.athlete.createdAt
              ..goalWeight = widget.athlete.goalWeight
              ..gender = widget.athlete.gender
              ..weightHistory = widget.athlete.weightHistory
              ..measurements = widget.athlete.measurements;
            try {
              await ref
                  .read(supabaseServiceProvider)
                  .updateAthlete(updatedAthlete);
              await ref.read(isarServiceProvider).updateAthlete(updatedAthlete);
              ref.read(athleteProvider.notifier).updateAthlete(updatedAthlete);
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
      ],
    );
  }
}
