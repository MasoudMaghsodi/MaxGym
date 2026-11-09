import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/config/supabase_config.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/remote/supabase_sync_service.dart';

void main() {
  group('Supabase API Payload Contract & Offline Resilience Tests', () {
    test('SupabaseConfig holds valid project URL and publishable key', () {
      expect(SupabaseConfig.supabaseUrl,
          equals('https://pnuyylukurndiflgzxmo.supabase.co'));
      expect(SupabaseConfig.supabasePublishableKey,
          startsWith('sb_publishable_'));
    });

    test('AthleteEntity.toSupabaseJson matches PostgreSQL column names exactly', () {
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
      expect(payload['last_name'], equals('Darvishi'));
      expect(payload['height_cm'], equals(185.0));
      expect(payload['weight_kg'], equals(92.0));
      expect(payload['fitness_goal'], equals('lean_bulk'));
      expect(payload['is_deleted'], isFalse);
      expect(payload.containsKey('sync_status'), isFalse); // نباید به سرور فرستاده شود
    });

    test('SupabaseSyncService handles offline state gracefully without throwing', () async {
      final db = LocalAppDatabase.initInMemoryForTesting();
      final syncService = SupabaseSyncService(db);

      // در محیط تست که Supabase مقداردهی شبکه نشده، باید بدون کرش وضعیت آفلاین را برگرداند
      final summary = await syncService.syncAllPendingData();
      expect(summary.success, isFalse);
      expect(summary.message.isNotEmpty, isTrue);
    });
  });
}
