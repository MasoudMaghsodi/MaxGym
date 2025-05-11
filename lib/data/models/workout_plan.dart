import 'package:isar/isar.dart';

part 'workout_plan.g.dart';

@collection
class WorkoutPlan {
  Id id = Isar.autoIncrement;

  @Index()
  String? supabaseId;

  String? name;

  List<Exercisee> exercises = [];

  @Index()
  String? athleteId;

  String? createdAt;

  String? status;

  String? endDate;
}

@embedded
class Exercisee {
  String? name;
  int? sets;
  int? reps;
  double? weight;
}
