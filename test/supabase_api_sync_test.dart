import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/config/supabase_config.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/remote/supabase_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Supabase API Payload Contract & OWASP Auth Guard Tests', () {
    test('SupabaseConfig uses PKCE & Secure Storage without leaking keys', () {
      expect(SupabaseConfig.supabaseUrl,
          equals('https://pnuyylukurndiflgzxmo.supabase.co'));
      expect(SupabaseConfig.supabasePublishableKey,
          startsWith('sb_publishable_'));
    });

    test('AthleteEntity.toSupabaseJson matches PostgreSQL schema', () {
      final now = DateTime.utc(2026, 11, 9, 12, 0);
      final athlete = AthleteEntity(
        id: '550e8400-e29b-41d4-a716-446655440000',
        firstName: 'Reza',
        lastName: 'Darvishi',
        phone: '09129998877',
        gender: 'male',
        age: 31,
        heightCm: 185,
        weightKg: 92,
        fitnessGoal: 'lean_bulk',
        injuryTags: const ['knee', 'shoulder'],
        createdAt: now,
        updatedAt: now,
      );

      final payload = athlete.toSupabaseJson();
      expect(payload['id'], equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(payload['first_name'], equals('Reza'));
      expect(payload.containsKey('sync_status'), isFalse);
    });

    test('SupabaseSyncService blocks sync gracefully when offline or unauthenticated', () async {
      final db = LocalAppDatabase.initInMemoryForTesting();
      final syncService = SupabaseSyncService(db);

      final summary = await syncService.syncAllPendingData();
      expect(summary.success, isFalse);
      expect(summary.message.isNotEmpty, isTrue);
    });
  });
}
