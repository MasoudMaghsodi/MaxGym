import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:max_gym/data/models/exercise.dart';
import 'package:max_gym/data/services/isar_service.dart';
import 'package:max_gym/data/services/supabase_service.dart';

final supabaseServiceProvider =
    Provider<SupabaseService>((ref) => SupabaseService());
final isarServiceProvider = Provider<IsarService>((ref) => IsarService());

final exerciseProvider =
    StateNotifierProvider<ExerciseNotifier, List<Exercise>>((ref) {
  return ExerciseNotifier(ref);
});

class ExerciseNotifier extends StateNotifier<List<Exercise>> {
  final Ref _ref;

  ExerciseNotifier(this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _ref.read(isarServiceProvider).getExercises().then((exercises) {
      state = exercises;
    });
    await _ref.read(supabaseServiceProvider).syncExercises();
    _ref.read(supabaseServiceProvider).subscribeToExercises(_loadExercises);
  }

  Future<void> _loadExercises() async {
    final exercises = await _ref.read(supabaseServiceProvider).fetchExercises();
    await _ref.read(isarServiceProvider).syncExercises(exercises);
    state = await _ref.read(isarServiceProvider).getExercises();
  }

  Future<void> addExercise(Exercise exercise) async {
    final supabaseId =
        await _ref.read(supabaseServiceProvider).addExercise(exercise);
    await _ref.read(isarServiceProvider).addExercise(exercise, supabaseId);
    state = [...state, exercise..supabaseId = supabaseId];
  }

  Future<void> updateExercise(Exercise exercise) async {
    await _ref
        .read(supabaseServiceProvider)
        .updateExercise(exercise.supabaseId!, exercise);
    await _ref.read(isarServiceProvider).updateExercise(exercise);
    state = [
      for (final e in state) e.supabaseId == exercise.supabaseId ? exercise : e
    ];
  }

  Future<void> deleteExercise(String supabaseId) async {
    await _ref.read(supabaseServiceProvider).deleteExercise(supabaseId);
    await _ref.read(isarServiceProvider).deleteExercise(supabaseId);
    state = state.where((e) => e.supabaseId != supabaseId).toList();
  }
}
