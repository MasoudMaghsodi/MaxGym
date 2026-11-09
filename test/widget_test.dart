import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_coach_app/main.dart';
import 'package:pro_coach_app/core/theme/branding_provider.dart';

void main() {
  testWidgets('ProCoachApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const ProCoachApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(ProCoachApp), findsOneWidget);
  });
}
