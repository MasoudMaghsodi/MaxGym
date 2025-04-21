import 'package:isar/isar.dart';

part 'athlete.g.dart';

@collection
class Athlete {
  Id id = Isar.autoIncrement;

  @Index()
  String? supabaseId;

  @Index()
  String? name;

  int? age;

  double? weight;

  String? createdAt;

  List<WeightEntry> weightHistory = [];

  double? goalWeight;

  String? gender;

  double? height;

  double? bodyFat;

  List<Measurement> measurements = [];
}

@embedded
class WeightEntry {
  String? date;
  double? weight;
}

@embedded
class Measurement {
  String? type;
  double? value;
  String? date;
}
