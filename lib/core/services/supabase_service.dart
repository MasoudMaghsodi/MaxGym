import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/athlete.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> addAthlete(Athlete athlete) async {
    await _client.from('athletes').insert({
      'name': athlete.name,
      'age': athlete.age,
      'weight': athlete.weight,
      'created_at': athlete.createdAt,
    });
  }

  Future<List<Athlete>> getAllAthletes() async {
    final response = await _client.from('athletes').select();
    return response
        .map((data) => Athlete()
          ..name = data['name']
          ..age = data['age']
          ..weight = data['weight']?.toDouble()
          ..createdAt = data['created_at'])
        .toList();
  }
}
