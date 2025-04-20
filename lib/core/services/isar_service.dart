import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/athlete.dart';

class IsarService {
  late Future<Isar> _db;

  IsarService() {
    _db = _initDb();
  }

  Future<Isar> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [AthleteSchema],
      directory: dir.path,
    );
  }

  Future<void> addAthlete(Athlete athlete) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.athletes.put(athlete);
    });
  }

  Future<List<Athlete>> getAllAthletes() async {
    final isar = await _db;
    return isar.athletes.where().findAll();
  }

  Future<void> deleteAthlete(Id id) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.athletes.delete(id);
    });
  }
}
