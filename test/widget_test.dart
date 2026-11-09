import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_coach_app/main.dart';
import 'package:pro_coach_app/core/theme/branding_provider.dart';
import 'package:pro_coach_app/data/local/app_database.dart';

void main() {
  testWidgets('ProCoachApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = LocalAppDatabase.inMemory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const ProCoachApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(ProCoachApp), findsOneWidget);
  });
}
