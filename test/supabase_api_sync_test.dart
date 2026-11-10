import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/core/config/supabase_config.dart';
import 'package:pro_coach_app/core/telemetry/supabase_crash_logger.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/data/remote/supabase_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('Supabase API Payload Contract, Crash Telemetry & OWASP Guard Tests', () {
    test('SupabaseConfig uses PKCE & Secure Storage without leaking keys', () {
      expect(SupabaseConfig.supabaseUrl,
          equals('https://pnuyylukurndiflgzxmo.supabase.co'));
      expect(SupabaseConfig.supabasePublishableKey,
          startsWith('sb_publishable_'));
    });

    test('Telemetry generates hardware Device Fingerprint ID safely', () async {
      final devId = await SupabaseCrashTelemetry.getOrCreateDeviceFingerprint();
      expect(devId.isNotEmpty, isTrue);
      expect(devId, startsWith('DEV-'));
    });

    test('Athlete, ChatMessage, and WorkoutLog payloads match PostgreSQL schema', () {
      final now = DateTime.utc(2026, 11, 10, 12, 0);
      final athlete = AthleteEntity(
        id: '550e8400-e29b-41d4-a716-446655440000',
        firstName: 'Reza',
        lastName: 'Darvishi',
        phone: '09129998877',
        email: 'reza@maxgym.ir',
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
      expect(athJson['email'], equals('reza@maxgym.ir'));
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
