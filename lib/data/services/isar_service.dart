import 'package:isar/isar.dart';
import 'package:max_gym/data/models/exercise.dart';
import 'package:path_provider/path_provider.dart';
import '../models/athlete.dart';
import '../models/workout_plan.dart';

class IsarService {
  static Isar? _isarInstance;
  late Future<Isar> _db;

  IsarService() {
    _db = _initDb();
  }

  Future<Isar> _initDb() async {
    if (_isarInstance != null) {
      return _isarInstance!;
    }
    final dir = await getApplicationDocumentsDirectory();
    _isarInstance = await Isar.open(
      [AthleteSchema, WorkoutPlanSchema],
      directory: dir.path,
    );
    return _isarInstance!;
  }

  // Athlete Methods
  Future<void> addAthlete(Athlete athlete, String supabaseId) async {
    final isar = await _db;
    athlete.supabaseId = supabaseId;
    athlete.weightHistory = [
      WeightEntry()
        ..date = DateTime.now().toIso8601String()
        ..weight = athlete.weight
    ];
    await isar.writeTxn(() async {
      await isar.athletes.put(athlete);
    });
  }

  Future<List<Athlete>> getAllAthletes() async {
    final isar = await _db;
    return isar.athletes.where().findAll();
  }

  Future<void> updateAthlete(Athlete athlete) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final existing = await isar.athletes
          .where()
          .filter()
          .supabaseIdEqualTo(athlete.supabaseId!)
          .findFirst();
      if (existing != null &&
          athlete.weight != null &&
          athlete.weight != existing.weight) {
        athlete.weightHistory = [
          ...existing.weightHistory,
          WeightEntry()
            ..date = DateTime.now().toIso8601String()
            ..weight = athlete.weight
        ];
      }
      await isar.athletes.put(athlete);
    });
  }

  Future<void> deleteAthlete(String supabaseId) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final athlete = await isar.athletes
          .where()
          .filter()
          .supabaseIdEqualTo(supabaseId)
          .findFirst();
      if (athlete != null) {
        await isar.athletes.delete(athlete.id);
      }
    });
  }

  Future<void> updateGoalWeight(String supabaseId, double goalWeight) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final athlete = await isar.athletes
          .where()
          .filter()
          .supabaseIdEqualTo(supabaseId)
          .findFirst();
      if (athlete != null) {
        athlete.goalWeight = goalWeight;
        await isar.athletes.put(athlete);
      }
    });
  }

  Future<void> syncAthletes(List<Athlete> remoteAthletes) async {
    final isar = await _db;
    final localAthletes = await getAllAthletes();
    await isar.writeTxn(() async {
      for (var local in localAthletes) {
        final remote = remoteAthletes.firstWhere(
          (r) => r.supabaseId == local.supabaseId,
          orElse: () => Athlete(),
        );
        if (remote.supabaseId == null) {
          await isar.athletes.put(local);
        } else if (local.createdAt!.compareTo(remote.createdAt!) > 0) {
          await isar.athletes.put(local);
        } else {
          await isar.athletes.put(remote);
        }
      }
    });
  }

  // Workout Plan Methods
  Future<void> addWorkoutPlan(WorkoutPlan plan, String supabaseId) async {
    final isar = await _db;
    plan.supabaseId = supabaseId;
    await isar.writeTxn(() async {
      await isar.workoutPlans.put(plan);
    });
  }

  Future<List<WorkoutPlan>> getWorkoutPlans(String athleteId) async {
    final isar = await _db;
    return isar.workoutPlans
        .where()
        .filter()
        .athleteIdEqualTo(athleteId)
        .findAll();
  }

  Future<void> updateWorkoutPlan(WorkoutPlan plan) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.workoutPlans.put(plan);
    });
  }

  Future<void> deleteWorkoutPlan(String supabaseId) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      final plan = await isar.workoutPlans
          .where()
          .filter()
          .supabaseIdEqualTo(supabaseId)
          .findFirst();
      if (plan != null) {
        await isar.workoutPlans.delete(plan.id);
      }
    });
  }

  // Exercise methods
  Future<void> addExercise(Exercise exercise, String supabaseId) async {
    await _isarInstance?.writeTxn(() async {
      final existing = await _isarInstance?.exercises
          .filter()
          .supabaseIdEqualTo(supabaseId)
          .findFirst();
      if (existing == null) {
        await _isarInstance?.exercises.put(exercise..supabaseId = supabaseId);
      }
    });
  }

  Future<void> updateExercise(Exercise exercise) async {
    await _isarInstance?.writeTxn(() async {
      await _isarInstance?.exercises.put(exercise);
    });
  }

  Future<void> deleteExercise(String supabaseId) async {
    await _isarInstance?.writeTxn(() async {
      await _isarInstance?.exercises
          .filter()
          .supabaseIdEqualTo(supabaseId)
          .deleteFirst();
    });
  }

  Future<List<Exercise>> getExercises() async {
    return await _isarInstance!.exercises.where().findAll();
  }

  Future<void> syncExercises(List<Exercise> exercises) async {
    await _isarInstance?.writeTxn(() async {
      await _isarInstance?.exercises.clear();
      await _isarInstance?.exercises.putAll(exercises);
    });
  }
}
