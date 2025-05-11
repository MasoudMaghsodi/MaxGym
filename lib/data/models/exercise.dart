import 'package:isar/isar.dart';

part 'exercise.g.dart';

@Collection()
class Exercise {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String? supabaseId;

  String? name;

  String? muscleGroup;

  String? description;

  String? createdAt;

  Exercise({
    this.supabaseId,
    this.name,
    this.muscleGroup,
    this.description,
    this.createdAt,
  });

  Exercise copyWith({
    String? supabaseId,
    String? name,
    String? muscleGroup,
    String? description,
    String? createdAt,
  }) {
    return Exercise(
      supabaseId: supabaseId ?? this.supabaseId,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
