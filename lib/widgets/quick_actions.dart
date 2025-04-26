import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:max_gym/l10n/app_localizations.dart';
import '../data/models/athlete.dart';
import '../providers/athlete_provider.dart';
import '../widgets/custom_text_field.dart';

class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: const Color(0xFF212121),
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.person_add, color: Colors.white),
            title: Text(l10n.translate('add_athlete'),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'Montserrat')),
            onTap: () {
              Navigator.pop(context);
              _showAddAthleteDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.fitness_center, color: Colors.white),
            title: Text(l10n.translate('quick_weight'),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'Montserrat')),
            onTap: () {
              Navigator.pop(context);
              _showQuickWeightDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAthleteDialog(
      BuildContext context, WidgetRef ref) async {
    // ignore: unused_local_variable
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (context) => _AddAthleteDialog(),
    );
  }

  Future<void> _showQuickWeightDialog(
      BuildContext context, WidgetRef ref) async {
    // ignore: unused_local_variable
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (context) => _QuickWeightDialog(),
    );
  }
}

class _AddAthleteDialog extends StatefulWidget {
  @override
  State<_AddAthleteDialog> createState() => _AddAthleteDialogState();
}

class _AddAthleteDialogState extends State<_AddAthleteDialog> {
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
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
      title: Text(l10n.translate('add_athlete')),
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
              final newAthlete = Athlete()
                ..name = _nameController.text
                ..weight = double.tryParse(_weightController.text)
                ..height = double.tryParse(_heightController.text)
                ..createdAt = DateTime.now().toIso8601String();
              try {
                final supabaseId = await ref
                    .read(supabaseServiceProvider)
                    .addAthlete(newAthlete);
                await ref
                    .read(isarServiceProvider)
                    .addAthlete(newAthlete, supabaseId);
                ref
                    .read(athleteProvider.notifier)
                    .addAthlete(newAthlete..supabaseId = supabaseId);
                // ignore: use_build_context_synchronously
                Navigator.pop(context, true);
              } catch (e) {
                // ignore: use_build_context_synchronously
                Navigator.pop(context, false);
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ),
      ],
    );
  }
}

class _QuickWeightDialog extends StatefulWidget {
  @override
  State<_QuickWeightDialog> createState() => _QuickWeightDialogState();
}

class _QuickWeightDialogState extends State<_QuickWeightDialog> {
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.translate('quick_weight')),
      content: CustomTextField(
        label: l10n.translate('weight'),
        controller: _weightController,
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.translate('cancel')),
        ),
        TextButton(
          onPressed: () {
            // Implement weight logging logic
            Navigator.pop(context);
          },
          child: Text(l10n.translate('save')),
        ),
      ],
    );
  }
}
