import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class FirebaseService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  Future<void> logEvent(
      {required String name, Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> logAthleteAdded(String athleteName) async {
    await logEvent(name: 'athlete_added', parameters: {'name': athleteName});
  }

  Future<void> logError(String error) async {
    await _crashlytics.recordError(Exception(error), null, reason: 'App Error');
  }
}
