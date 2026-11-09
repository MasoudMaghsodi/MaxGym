import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/local/app_database.dart';

final athleteSearchQueryProvider = StateProvider<String>((ref) => '');

final athletesProvider =
    StateNotifierProvider<AthletesNotifier, List<AthleteEntity>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AthletesNotifier(db);
});

final athletesListProvider = athletesProvider;

final filteredAthletesProvider = Provider<List<AthleteEntity>>((ref) {
  final all = ref.watch(athletesProvider);
  final query = ref.watch(athleteSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return all;
  return all.where((a) {
    return a.fullName.toLowerCase().contains(query) ||
        a.phone.contains(query) ||
        a.accessCode.toLowerCase().contains(query);
  }).toList();
});

class AthletesNotifier extends StateNotifier<List<AthleteEntity>> {
  final LocalAppDatabase _db;
  static const _uuid = Uuid();

  AthletesNotifier(this._db) : super([]) {
    refresh();
  }

  void refresh() {
    state = _db.getAllActiveAthletes();
  }

  Future<AthleteEntity> createOrUpdateAthlete({
    String? existingId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
    required List<String> injuryTags,
    double? bodyFatPercent,
    double? shoulderCm,
    double? chestCm,
    double? waistCm,
    double? hipsCm,
    double? bicepsCm,
    double? forearmCm,
    double? thighCm,
    double? calfCm,
  }) async {
    final now = DateTime.now();
    final id = existingId ?? _uuid.v4();

    // حفظ تاریخ ثبت‌نام، ایمیل و کد ورود ۶ رقمی اختصاصی ورزشکار در صورت ویرایش
    final existingRecord =
        existingId != null ? _db.getAthleteById(existingId) : null;
    final createdDate = existingRecord?.createdAt ?? now;
    final preservedEmail = email ?? existingRecord?.email ?? '';
    final preservedAccessCode =
        (existingRecord != null && existingRecord.accessCode.isNotEmpty)
            ? existingRecord.accessCode
            : AthleteEntity.generateAccessCode();

    final athlete = AthleteEntity(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: preservedEmail,
      accessCode: preservedAccessCode,
      gender: gender,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      fitnessGoal: fitnessGoal,
      injuryTags: injuryTags,
      createdAt: createdDate,
      updatedAt: now,
      syncStatus: existingId == null ? 'pending_insert' : 'pending_update',
    );

    _db.upsertAthlete(athlete);

    final hasAnyMeasurement = bodyFatPercent != null ||
        shoulderCm != null ||
        chestCm != null ||
        waistCm != null ||
        hipsCm != null ||
        bicepsCm != null ||
        forearmCm != null ||
        thighCm != null ||
        calfCm != null ||
        existingId == null;

    if (hasAnyMeasurement) {
      final log = MeasurementLogEntity(
        id: _uuid.v4(),
        athleteId: id,
        recordedAt: now,
        weightKg: weightKg,
        bodyFatPercent: bodyFatPercent,
        shoulderCm: shoulderCm,
        chestCm: chestCm,
        waistCm: waistCm,
        hipsCm: hipsCm,
        bicepsCm: bicepsCm,
        forearmCm: forearmCm,
        thighCm: thighCm,
        calfCm: calfCm,
        updatedAt: now,
      );
      _db.insertMeasurementLog(log);
    }

    refresh();
    return athlete;
  }

  void addMeasurementCheckIn(MeasurementLogEntity log) {
    _db.insertMeasurementLog(log);
    refresh();
  }

  void deleteAthlete(String id) {
    _db.softDeleteAthlete(id);
    refresh();
  }
}
