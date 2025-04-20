import 'package:isar/isar.dart';

part 'athlete.g.dart';

@collection
class Athlete {
  Id id = Isar.autoIncrement;

  @Index()
  String? name;

  int? age;

  double? weight;

  String? createdAt;
}
