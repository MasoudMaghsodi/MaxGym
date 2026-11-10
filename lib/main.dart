import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/maxgym_brand_config.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'core/localization/app_localizations.dart';
import 'core/telemetry/supabase_crash_logger.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/branding_provider.dart';
import 'core/widgets/responsive_shell.dart';
import 'data/local/app_database.dart';
import 'data/remote/supabase_sync_service.dart';
import 'features/athletes/presentation/athletes_list_screen.dart';
import 'features/athletes/presentation/athletes_provider.dart';
import 'features/auth/security_gate_screen.dart';
import 'features/dashboard/presentation/coach_dashboard_screen.dart';
import 'features/pdf_export/pdf_export_engine.dart';
import 'features/settings/presentation/branding_settings_screen.dart';
import 'features/splash/maxgym_3d_splash_screen.dart';
import 'features/workout_builder/presentation/master_program_builder_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ۰. راه‌اندازی مانیتورینگ سراسری تلمتری کرش و خطاهای سیستم در Supabase
  SupabaseCrashTelemetry.initializeGlobalErrorHandling();

  // ۱. راه‌اندازی SharedPreferences برای برندینگ و تم
  final prefs = await SharedPreferences.getInstance();

  // ۲. راهاندازی دیتابیس آفلاین SQLite به عنوان Single Source of Truth
  final localDb = await LocalAppDatabase.init();

  // ۳. راهاندازی ایمن Supabase با URL و Publishable Key شما (بدون بلاک کردن حالت آفلاین)
  await SupabaseConfig.initializeSafely();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(localDb),
      ],
      child: const ProCoachApp(),
    ),
  );
}

class ProCoachApp extends ConsumerStatefulWidget {
  const ProCoachApp({super.key});

  @override
  ConsumerState<ProCoachApp> createState() => _ProCoachAppState();
}

class _ProCoachAppState extends ConsumerState<ProCoachApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supabaseSyncServiceProvider).startAutoSyncListener();
    });
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);

    // اجرای خودکار سینک ابری به محض عبور موفق مربی از گارد امنیتی و تایید ادمین
    ref.listen<SecurityGateState>(securityGateProvider, (previous, next) {
      if (next.status == SecurityGateStatus.authorizedAndActive &&
          previous?.status != SecurityGateStatus.authorizedAndActive) {
        ref.read(supabaseSyncServiceProvider).syncAllPendingData().then((_) {
          ref.read(athletesProvider.notifier).refresh();
        });
      }
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: MaxGymBrandConfig.appName,
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
      home: const MaxGym3DSplashScreen(
        nextScreen: SecurityGateWrapper(
          authorizedChild: MainNavigationShell(),
        ),
      ),
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

  /// باز کردن طراح جامع برنامه (تمرین + تغذیه + مکمل + پکیج مالی) برای ورزشکار
  Future<void> _openProgramBuilderForAthlete(AthleteEntity athlete) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MasterProgramBuilderScreen(
          athlete: athlete,
          onSavedAndExportPdf: (ath, prog) {
            _showPdfLanguageSelectorAndExport(ath, prog);
          },
        ),
      ),
    );
    ref.read(athletesProvider.notifier).refresh();
    setState(() {});
  }

  /// انتخاب زبان خروجی PDF (فارسی، انگلیسی یا دوزبانه) و تولید فایل با نام داینامیک شمسی
  void _showPdfLanguageSelectorAndExport(
      AthleteEntity athlete, FullProgramEntity program) {
    final hostContext = context;
    final isFa = AppStrings.of(hostContext).isFa;
    final db = ref.read(appDatabaseProvider);
    final branding = ref.read(brandingProvider);
    final measurements = db.getMeasurementsForAthlete(athlete.id);
    final previewFileName =
        PdfExportEngine.buildDynamicFileName(athlete, program.startDate);

    showModalBottomSheet(
      context: hostContext,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFa
                    ? 'تولید و اشتراکگذاری PDF اختصاصی'
                    : 'Export Custom White-Label PDF',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '📄 $previewFileName',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(hostContext).colorScheme.primary,
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(LucideIcons.languages),
                title: Text(isFa
                    ? 'دوزبانه تخصصی (فارسی + اصطلاحات انگلیسی)'
                    : 'Bilingual (Persian + English Terms)'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (hostContext.mounted) {
                    PdfExportEngine.generateAndShareProgramPdf(
                      context: hostContext,
                      branding: branding,
                      athlete: athlete,
                      program: program,
                      measurements: measurements,
                      langMode: PdfLanguageMode.bilingual,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.fileText),
                title: Text(isFa ? 'فقط فارسی (RTL)' : 'Persian Only (RTL)'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (hostContext.mounted) {
                    PdfExportEngine.generateAndShareProgramPdf(
                      context: hostContext,
                      branding: branding,
                      athlete: athlete,
                      program: program,
                      measurements: measurements,
                      langMode: PdfLanguageMode.persianOnly,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.globe),
                title: Text(
                    isFa ? 'فقط انگلیسی (بینالمللی - LTR)' : 'English Only (LTR)'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (hostContext.mounted) {
                    PdfExportEngine.generateAndShareProgramPdf(
                      context: hostContext,
                      branding: branding,
                      athlete: athlete,
                      program: program,
                      measurements: measurements,
                      langMode: PdfLanguageMode.englishOnly,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _triggerManualSync() async {
    final res =
        await ref.read(supabaseSyncServiceProvider).syncAllPendingData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    final pages = [
      CoachDashboardScreen(
        onTriggerCloudSync: _triggerManualSync,
        onOpenWorkoutBuilder: _openProgramBuilderForAthlete,
        onExportPdf: _showPdfLanguageSelectorAndExport,
      ),
      AthletesListScreen(
        onOpenWorkoutBuilder: _openProgramBuilderForAthlete,
        onExportPdf: _showPdfLanguageSelectorAndExport,
      ),
      const TemplatesScreen(),
      const BrandingSettingsScreen(),
    ];

    return MaxGymResponsiveScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
      pages: pages,
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
    );
  }
}
