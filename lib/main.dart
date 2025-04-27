import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:max_gym/core/theme/theme.dart';
import 'package:max_gym/data/services/notification_service.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:max_gym/screens/splash_screen.dart';
import 'core/config/supabase_config.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SupabaseConfig.initialize();
  final notificationService = NotificationService();
  await notificationService.init();
  runApp(const ProviderScope(child: MyApp()));
}

final localeProvider = StateProvider<Locale>((ref) => const Locale('en', 'US'));

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Max Gym',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: ref.watch(localeProvider),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('fa', 'IR'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
