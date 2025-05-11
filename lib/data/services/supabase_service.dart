import 'package:max_gym/data/models/exercise.dart';
import 'package:max_gym/data/models/workout_plan.dart';
import 'package:max_gym/data/services/isar_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/athlete.dart';
import 'notification_service.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  SupabaseService() {
    _setupRealtime();
  }

  void _setupRealtime() {
    _client
        .channel('workout_plans')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'workout_plans',
          callback: (payload) async {
            final updatedPlan = payload.newRecord;
            if (updatedPlan['status'] == 'completed') {
              final athleteId = updatedPlan['athlete_id'];
              final athlete = await _client
                  .from('athletes')
                  .select('name')
                  .eq('id', athleteId)
                  .single();
              final notificationTitle = 'برنامه تمرینی تمام شد';
              final notificationBody =
                  'برنامه ${athlete['name']} تمام شده، لطفاً آپدیت کنید!';

              // ذخیره اعلان توی جدول notifications
              await _client.from('notifications').insert({
                'title': notificationTitle,
                'body': notificationBody,
                'athlete_id': athleteId,
              });

              // نمایش اعلان محلی
              await _notificationService.showNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: notificationTitle,
                body: notificationBody,
              );
            }
          },
        )
        .subscribe();
  }

  Future<String> addAthlete(Athlete athlete) async {
    final data = {
      'name': athlete.name,
      'age': athlete.age,
      'weight': athlete.weight,
      'created_at': athlete.createdAt,
      'weight_history': [
        {'date': DateTime.now().toIso8601String(), 'weight': athlete.weight}
      ],
      'height': athlete.height,
      'body_fat': athlete.bodyFat,
      'measurements': athlete.measurements
          .map((m) => {'type': m.type, 'value': m.value, 'date': m.date})
          .toList(),
    };
    if (athlete.goalWeight != null) {
      data['goal_weight'] = athlete.goalWeight;
    }
    if (athlete.gender != null) {
      data['gender'] = athlete.gender;
    }
    final response =
        await _client.from('athletes').insert(data).select('id').single();
    return response['id'] as String;
  }

  Future<List<Athlete>> getAllAthletes() async {
    final response = await _client.from('athletes').select();
    return response.map((data) {
      final athlete = Athlete()
        ..supabaseId = data['id']
        ..name = data['name']
        ..age = data['age']
        ..weight = data['weight']?.toDouble()
        ..createdAt = data['created_at']
        ..goalWeight = data['goal_weight']?.toDouble()
        ..gender = data['gender']
        ..height = data['height']?.toDouble()
        ..bodyFat = data['body_fat']?.toDouble();
      if (data['weight_history'] != null) {
        athlete.weightHistory = (data['weight_history'] as List).map((entry) {
          return WeightEntry()
            ..date = entry['date']
            ..weight = entry['weight']?.toDouble();
        }).toList();
      }
      if (data['measurements'] != null) {
        athlete.measurements = (data['measurements'] as List).map((entry) {
          return Measurement()
            ..type = entry['type']
            ..value = entry['value']?.toDouble()
            ..date = entry['date'];
        }).toList();
      }
      return athlete;
    }).toList();
  }

  Future<void> updateAthlete(Athlete athlete) async {
    final existing = await _client
        .from('athletes')
        .select('weight, weight_history, measurements')
        .eq('id', athlete.supabaseId!)
        .single();
    final newHistory = [
      ...existing['weight_history'] ?? [],
      if (athlete.weight != null && athlete.weight != existing['weight'])
        {'date': DateTime.now().toIso8601String(), 'weight': athlete.weight}
    ];
    final data = {
      'name': athlete.name,
      'age': athlete.age,
      'weight': athlete.weight,
      'created_at': athlete.createdAt,
      'weight_history': newHistory,
      'height': athlete.height,
      'body_fat': athlete.bodyFat,
      'measurements': athlete.measurements
          .map((m) => {'type': m.type, 'value': m.value, 'date': m.date})
          .toList(),
    };
    if (athlete.goalWeight != null) {
      data['goal_weight'] = athlete.goalWeight;
    }
    if (athlete.gender != null) {
      data['gender'] = athlete.gender;
    }
    await _client.from('athletes').update(data).eq('id', athlete.supabaseId!);
  }

  Future<void> deleteAthlete(String supabaseId) async {
    await _client.from('athletes').delete().eq('id', supabaseId);
  }

  Future<void> syncAthletes() async {
    final remoteAthletes = await getAllAthletes();
    final isarService = IsarService();
    final localAthletes = await isarService.getAllAthletes();
    for (var local in localAthletes) {
      final remote = remoteAthletes.firstWhere(
        (r) => r.supabaseId == local.supabaseId,
        orElse: () => Athlete(),
      );
      if (remote.supabaseId == null) {
        await addAthlete(local);
      } else if (local.createdAt!.compareTo(remote.createdAt!) > 0) {
        await updateAthlete(local);
      }
    }
    await isarService.syncAthletes(remoteAthletes);
  }

  Future<String> addWorkoutPlan(WorkoutPlan plan) async {
    final data = {
      'name': plan.name,
      'exercises': plan.exercises
          .map((e) => {
                'name': e.name,
                'sets': e.sets,
                'reps': e.reps,
                'weight': e.weight
              })
          .toList(),
      'athlete_id': plan.athleteId,
      'created_at': plan.createdAt,
      'status': plan.status,
      'end_date': plan.endDate,
    };
    final response =
        await _client.from('workout_plans').insert(data).select('id').single();
    return response['id'] as String;
  }

  Future<List<WorkoutPlan>> getWorkoutPlans(String athleteId) async {
    final response = await _client
        .from('workout_plans')
        .select()
        .eq('athlete_id', athleteId);
    return response.map((data) {
      final plan = WorkoutPlan()
        ..supabaseId = data['id']
        ..name = data['name']
        ..athleteId = data['athlete_id']
        ..createdAt = data['created_at']
        ..status = data['status']
        ..endDate = data['end_date'];
      if (data['exercises'] != null) {
        plan.exercises = (data['exercises'] as List).map((entry) {
          return Exercisee()
            ..name = entry['name']
            ..sets = entry['sets']
            ..reps = entry['reps']
            ..weight = entry['weight']?.toDouble();
        }).toList();
      }
      return plan;
    }).toList();
  }

  Future<void> updateWorkoutPlan(WorkoutPlan plan) async {
    final data = {
      'name': plan.name,
      'exercises': plan.exercises
          .map((e) => {
                'name': e.name,
                'sets': e.sets,
                'reps': e.reps,
                'weight': e.weight
              })
          .toList(),
      'athlete_id': plan.athleteId,
      'created_at': plan.createdAt,
      'status': plan.status,
      'end_date': plan.endDate,
    };
    await _client.from('workout_plans').update(data).eq('id', plan.supabaseId!);
  }

  Future<void> deleteWorkoutPlan(String supabaseId) async {
    await _client.from('workout_plans').delete().eq('id', supabaseId);
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _client.from('notifications').select();
    // ignore: unnecessary_cast
    return response as List<Map<String, dynamic>>;
  }

  void subscribeToAthletes(void Function() onUpdate) {
    Supabase.instance.client
        .from('athletes')
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      onUpdate();
    });
  }

  // Exercise methods
  Future<String> addExercise(Exercise exercise) async {
    final response = await _client
        .from('exercises')
        .insert({
          'name': exercise.name,
          'muscle_group': exercise.muscleGroup,
          'description': exercise.description,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();
    return response['id'].toString();
  }

  Future<void> updateExercise(String supabaseId, Exercise exercise) async {
    await _client.from('exercises').update({
      'name': exercise.name,
      'muscle_group': exercise.muscleGroup,
      'description': exercise.description,
    }).eq('id', supabaseId);
  }

  Future<void> deleteExercise(String supabaseId) async {
    await _client.from('exercises').delete().eq('id', supabaseId);
  }

  Future<List<Exercise>> fetchExercises() async {
    final response = await _client.from('exercises').select();
    return response
        .map((data) => Exercise(
              supabaseId: data['id'].toString(),
              name: data['name'],
              muscleGroup: data['muscle_group'],
              description: data['description'],
              createdAt: data['created_at'],
            ))
        .toList();
  }

  void subscribeToExercises(void Function() callback) {
    _client
        .channel('exercises')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'exercises',
            callback: (_) => callback())
        .subscribe();
  }

  Future<void> syncExercises() async {
    await fetchExercises();
  }
}
