import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/branding_provider.dart';
import 'data/local/app_database.dart';
import 'features/settings/presentation/branding_settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final database = await LocalAppDatabase.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const ProCoachApp(),
    ),
  );
}

class ProCoachApp extends ConsumerWidget {
  const ProCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ProCoach',
      locale: branding.locale,
      supportedLocales: const [
        Locale('fa'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: branding.themeMode,
      theme: AppTheme.buildTheme(branding, Brightness.light),
      darkTheme: AppTheme.buildTheme(branding, Brightness.dark),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final branding = ref.watch(brandingProvider);

    final pages = [
      // در گام ۳ تا ۵ این ۳ تب با صفحات واقعی داشبورد، ورزشکاران و قالبها جایگزین میشوند
      Center(
        child: Text(
          '${s.tr('dashboard')} - ${branding.gymName}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      Center(child: Text(s.tr('athletes'))),
      Center(child: Text(s.tr('templates'))),
      const BrandingSettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.layoutDashboard),
            label: s.tr('dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.users),
            label: s.tr('athletes'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.copy),
            label: s.tr('templates'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.settings),
            label: s.tr('settings'),
          ),
        ],
      ),
    );
  }
}
