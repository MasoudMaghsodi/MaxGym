import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_coach_app/data/local/app_database.dart';
import 'package:pro_coach_app/features/athlete_portal/athlete_portal_screen.dart';
import 'package:pro_coach_app/features/auth/security_gate_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Dual-Role & Athlete Portal Tests', () {
    late LocalAppDatabase db;

    setUp(() {
      db = LocalAppDatabase.initInMemoryForTesting();
    });

    testWidgets('Shows Mandatory Profile Completion Gate when profile is incomplete',
        (tester) async {
      final incompleteAthlete = AthleteEntity(
        id: 'ath_inc_1',
        firstName: '',
        lastName: '',
        phone: '123',
        email: '',
        accessCode: 'PC-112233',
        gender: 'male',
        age: 25,
        heightCm: 175,
        weightKg: 75,
        fitnessGoal: 'lean_bulk',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: AthletePortalScreen(initialAthlete: incompleteAthlete),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تکمیل اجباری پرونده ورزشی شما'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Shows full portal navigation when profile is complete',
        (tester) async {
      final completeAthlete = AthleteEntity(
        id: 'ath_comp_1',
        firstName: 'آرش',
        lastName: 'کمانگیر',
        phone: '09121112233',
        email: 'arash@archer.ir',
        accessCode: 'PC-999000',
        gender: 'male',
        age: 28,
        heightCm: 182,
        weightKg: 85,
        fitnessGoal: 'muscle_gain',
        injuryTags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: AthletePortalScreen(initialAthlete: completeAthlete),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('آرش کمانگیر'), findsOneWidget);
      expect(find.text('تمرین امروز و رکورد'), findsOneWidget);
      expect(find.text('تغذیه، مکمل و آب'), findsOneWidget);
      expect(find.text('گفتگو با مربی'), findsOneWidget);
    });

    testWidgets('CoachAuthScreen toggles smoothly between Coach Mode and Athlete Mode',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: CoachAuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ورود امن مربی به سامانه'), findsOneWidget);
      expect(find.text('ایمیل مربی'), findsOneWidget);

      // Switch to Athlete Mode
      await tester.tap(find.text('پنل ورزشکار'));
      await tester.pumpAndSettle();

      expect(find.text('ورود ورزشکار به برنامه آنلاین'), findsOneWidget);
      expect(find.text('کد اختصاصی ورزشکار (مثلاً PC-849201)'), findsOneWidget);
    });

    test('Auto-Draft round-trip serializes and parses FullProgramEntity properly', () {
      final program = FullProgramEntity(
        id: 'prog_draft_1',
        athleteId: 'ath_draft_roundtrip',
        title: 'پیش‌نویس تست سیستم',
        startDate: DateTime.now(),
        durationWeeks: 6,
        days: const [
          WorkoutDayPlan(
            dayNumber: 1,
            dayNameFa: 'شنبه',
            dayNameEn: 'Saturday',
            isRestDay: false,
            targetMuscles: ['chest'],
            exercises: [],
          ),
        ],
        dietMeals: const [],
        waterLiters: 4.0,
        dietGuidelines: const ['مصرف سالاد فراوان'],
        supplements: const [],
        totalFee: 1500000,
        paidAmount: 500000,
        paymentStatus: 'partial',
        updatedAt: DateTime.now(),
      );

      db.saveProgramDraft('ath_draft_roundtrip', program);

      final loaded = db.getProgramDraft('ath_draft_roundtrip');
      expect(loaded, isNotNull);
      expect(loaded!.title, equals('پیش‌نویس تست سیستم'));
      expect(loaded.durationWeeks, equals(6));
      expect(loaded.totalFee, equals(1500000));
      expect(loaded.waterLiters, equals(4.0));
      expect(loaded.dietGuidelines.first, equals('مصرف سالاد فراوان'));

      db.clearProgramDraft('ath_draft_roundtrip');
      expect(db.getProgramDraft('ath_draft_roundtrip'), isNull);
    });
  });
}
