import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/athlete.dart';
import '../core/services/isar_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/firebase_service.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';

final isarServiceProvider = Provider<IsarService>((ref) => IsarService());
final supabaseServiceProvider =
    Provider<SupabaseService>((ref) => SupabaseService());
final firebaseServiceProvider =
    Provider<FirebaseService>((ref) => FirebaseService());

final athletesProvider = FutureProvider<List<Athlete>>((ref) async {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.getAllAthletes();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _addAthlete() async {
    final isarService = ref.read(isarServiceProvider);
    final supabaseService = ref.read(supabaseServiceProvider);
    final firebaseService = ref.read(firebaseServiceProvider);

    final athlete = Athlete()
      ..name = _nameController.text
      ..age = int.tryParse(_ageController.text)
      ..weight = double.tryParse(_weightController.text)
      ..createdAt = DateTime.now().toIso8601String();

    try {
      await isarService.addAthlete(athlete);
      await supabaseService.addAthlete(athlete);
      await firebaseService.logAthleteAdded(athlete.name ?? '');
      _nameController.clear();
      _ageController.clear();
      _weightController.clear();
      // ignore: unused_result
      ref.refresh(athletesProvider);
    } catch (e) {
      await firebaseService.logError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final athletesAsync = ref.watch(athletesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Max Gym Dashboard')),
      body: Column(
        children: [
          CustomCard(
            title: 'Add Athlete',
            child: Column(
              children: [
                CustomTextField(
                  label: 'Name',
                  controller: _nameController,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  label: 'Age',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  label: 'Weight (kg)',
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'Add Athlete',
                  onPressed: _addAthlete,
                ),
              ],
            ),
          ),
          Expanded(
            child: athletesAsync.when(
              data: (athletes) => ListView.builder(
                itemCount: athletes.length,
                itemBuilder: (context, index) {
                  final athlete = athletes[index];
                  return CustomCard(
                    child: ListTile(
                      title: Text(athlete.name ?? 'Unknown'),
                      subtitle: Text(
                          'Age: ${athlete.age ?? '-'}, Weight: ${athlete.weight ?? '-'} kg'),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
