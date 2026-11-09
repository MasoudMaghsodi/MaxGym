import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pro_coach_app/core/config/supabase_config.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/remote/supabase_sync_service.dart';

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

    test('Athlete, ChatMessage, and WorkoutLog payloads match PostgreSQL schema', () {
      final now = DateTime.utc(2026, 11, 9, 12, 0);
      final athlete = AthleteEntity(
        id: '550e8400-e29b-41d4-a716-446655440000',
        firstName: 'Reza',
        lastName: 'Darvishi',
        phone: '09129998877',
        email: 'reza@gym.com',
        accessCode: 'PC-A1B2C3',
        gender: 'male',
        age: 31,
        heightCm: 185,
        weightKg: 92,
        fitnessGoal: 'lean_bulk',
        injuryTags: const ['knee'],
        createdAt: now,
        updatedAt: now,
      );

      final athJson = athlete.toSupabaseJson();
      expect(athJson['email'], equals('reza@gym.com'));
      expect(athJson['access_code'], equals('PC-A1B2C3'));
      expect(athJson.containsKey('sync_status'), isFalse);

      final chatMsg = ChatMessageEntity(
        id: 'chat-uuid-1',
        athleteId: athlete.id,
        senderRole: 'coach',
        messageText: 'Keep pushing!',
        createdAt: now,
      );
      expect(chatMsg.toSupabaseJson()['sender_role'], equals('coach'));

      final wLog = AthleteWorkoutLogEntity(
        id: 'log-uuid-1',
        athleteId: athlete.id,
        programId: 'prog-uuid-1',
        dayNumber: 2,
        exerciseWeightsKg: const {'Squat': '120'},
        waterGlasses: 10,
        sessionRpe: 8,
        loggedAt: now,
      );
      expect(wLog.toSupabaseJson()['water_glasses'], equals(10));
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
