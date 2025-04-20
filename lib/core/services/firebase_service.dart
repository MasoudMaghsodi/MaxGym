import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class FirebaseService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logAthleteAdded(String athleteName) async {
    await _analytics.logEvent(
      name: 'athlete_added',
      parameters: {'name': athleteName},
    );
  }

  Future<void> logError(String error) async {
    await FirebaseCrashlytics.instance.recordError(error, null, fatal: false);
  }
}
