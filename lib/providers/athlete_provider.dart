import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/athlete.dart';
import '../data/models/workout_plan.dart';
import '../data/services/isar_service.dart';
import '../data/services/supabase_service.dart';
import '../data/services/firebase_service.dart';

final isarServiceProvider = Provider<IsarService>((ref) => IsarService());
final supabaseServiceProvider =
    Provider<SupabaseService>((ref) => SupabaseService());
final firebaseServiceProvider =
    Provider<FirebaseService>((ref) => FirebaseService());

final athleteProvider =
    StateNotifierProvider<AthletesNotifier, List<Athlete>>((ref) {
  return AthletesNotifier(ref);
});

class AthletesNotifier extends StateNotifier<List<Athlete>> {
  final Ref ref;

  AthletesNotifier(this.ref) : super([]) {
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    try {
      final athletes = await ref.read(isarServiceProvider).getAllAthletes();
      state = athletes;
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  void addAthlete(Athlete athlete) {
    state = [...state, athlete];
  }

  void updateAthlete(Athlete updated) {
    state = [
      for (var athlete in state)
        athlete.supabaseId == updated.supabaseId ? updated : athlete
    ];
  }

  void deleteAthlete(String supabaseId) {
    state = state.where((athlete) => athlete.supabaseId != supabaseId).toList();
  }

  void updateGoal(String supabaseId, double goalWeight) {
    state = [
      for (var athlete in state)
        athlete.supabaseId == supabaseId
            ? (athlete..goalWeight = goalWeight)
            : athlete
    ];
  }
}

final workoutPlanProvider = StateNotifierProvider.family<WorkoutPlansNotifier,
    List<WorkoutPlan>, String>(
  (ref, athleteId) => WorkoutPlansNotifier(ref, athleteId),
);

class WorkoutPlansNotifier extends StateNotifier<List<WorkoutPlan>> {
  final Ref ref;
  final String athleteId;

  WorkoutPlansNotifier(this.ref, this.athleteId) : super([]) {
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans =
          await ref.read(isarServiceProvider).getWorkoutPlans(athleteId);
      state = plans;
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  void addPlan(WorkoutPlan plan) {
    state = [...state, plan];
  }

  void updatePlan(WorkoutPlan updated) {
    state = [
      for (var plan in state)
        plan.supabaseId == updated.supabaseId ? updated : plan
    ];
  }

  void deletePlan(String supabaseId) {
    state = state.where((plan) => plan.supabaseId != supabaseId).toList();
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
