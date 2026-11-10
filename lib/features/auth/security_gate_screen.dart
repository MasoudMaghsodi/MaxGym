import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/branding_provider.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_models.dart';
import '../athlete_portal/athlete_portal_screen.dart';

enum SecurityGateStatus {
  loading,
  unauthenticated,
  pendingAdminApproval,
  suspendedKillSwitch,
  authorizedAndActive, // ورود به پنل مربی
  athletePortalActive, // ورود به پنل ورزشکار
}

class SecurityGateState {
  final SecurityGateStatus status;
  final String? coachFullName;
  final String? email;
  final AthleteEntity? loggedInAthlete;
  final String lockTitle;
  final String lockMessage;
  final String developerContact;
  final String? errorMessage;

  const SecurityGateState({
    required this.status,
    this.coachFullName,
    this.email,
    this.loggedInAthlete,
    this.lockTitle = 'دسترسی به اپلیکیشن مسدود شده است',
    this.lockMessage =
        'به علت عدم تسویه حساب یا نقض قوانین، دسترسی شما توسط توسعه‌دهنده غیرفعال شده است.',
    this.developerContact = 'Support / Developer Contact',
    this.errorMessage,
  });
}

final securityGateProvider =
    StateNotifierProvider<SecurityGateNotifier, SecurityGateState>((ref) {
  return SecurityGateNotifier(ref);
});

class SecurityGateNotifier extends StateNotifier<SecurityGateState> {
  final Ref _ref;
  static const _secureStore = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kCachedApproved = 'sec_cached_is_approved';
  static const _kCachedSuspended = 'sec_cached_is_suspended';
  static const _kCachedLockMsg = 'sec_cached_lock_msg';
  static const _kCachedDevContact = 'sec_cached_dev_contact';
  static const _kCachedAthleteCode = 'sec_cached_athlete_code';

  StreamSubscription<List<Map<String, dynamic>>>? _appControlRealtimeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _coachProfileRealtimeSub;

  SecurityGateNotifier(this._ref)
      : super(const SecurityGateState(status: SecurityGateStatus.loading)) {
    verifySecurityAndSession().then((_) => _startRealtimeSecurityListeners());
  }

  /// شنود بلادرنگ (Realtime WebSocket) تغییرات پنل Supabase بدون نیاز به رفرش دستی
  void _startRealtimeSecurityListeners() {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;

    // ۱. شنود زنده جدول app_control برای قفل سراسری آنی
    _appControlRealtimeSub?.cancel();
    _appControlRealtimeSub = client
        .from('app_control')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .listen((rows) {
      if (rows.isNotEmpty) {
        verifySecurityAndSession();
      }
    }, onError: (_) {});

    // ۲. شنود زنده جدول coach_profiles برای تایید یا مسدودسازی آنی مربی در لحظه
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      _coachProfileRealtimeSub?.cancel();
      _coachProfileRealtimeSub = client
          .from('coach_profiles')
          .stream(primaryKey: ['id'])
          .eq('id', uid)
          .listen((rows) {
        if (rows.isNotEmpty) {
          verifySecurityAndSession();
        }
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _appControlRealtimeSub?.cancel();
    _coachProfileRealtimeSub?.cancel();
    super.dispose();
  }

  Future<void> verifySecurityAndSession() async {
    state = const SecurityGateState(status: SecurityGateStatus.loading);

    if (!SupabaseConfig.isInitialized) {
      await SupabaseConfig.initializeSafely();
    }
    final client = SupabaseConfig.clientOrNull;

    if (client == null) {
      await _evaluateOfflineSecurityFallback();
      return;
    }

    try {
      // ۱. بررسی Kill-Switch سراسری در جدول app_control
      final appControl = await client
          .from('app_control')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (appControl != null && (appControl['is_app_disabled'] == true)) {
        final title = appControl['lock_title_fa'] as String? ??
            'دسترسی به اپلیکیشن غیرفعال است';
        final msg = appControl['lock_message_fa'] as String? ??
            'لطفاً با توسعه‌دهنده تماس بگیرید.';
        final contact = appControl['developer_contact'] as String? ?? '';

        await _secureStore.write(key: _kCachedSuspended, value: 'true');
        await _secureStore.write(key: _kCachedLockMsg, value: msg);
        await _secureStore.write(key: _kCachedDevContact, value: contact);

        state = SecurityGateState(
          status: SecurityGateStatus.suspendedKillSwitch,
          lockTitle: title,
          lockMessage: msg,
          developerContact: contact,
        );
        return;
      }

      // ۲. اگر قبلاً ورزشکار با کد اختصاصی لاگین کرده بود، مستقیم وارد پنل ورزشکار شو
      final savedAthleteCode =
          await _secureStore.read(key: _kCachedAthleteCode);
      if (savedAthleteCode != null && savedAthleteCode.isNotEmpty) {
        await signInAthleteByCode(savedAthleteCode);
        return;
      }

      // ۳. بررسی نشست مربی (Session JWT)
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (session == null || user == null) {
        state = const SecurityGateState(
            status: SecurityGateStatus.unauthenticated);
        return;
      }

      // ۴. بررسی وضعیت تایید ادمین و مسدودیت تکی مربی در جدول coach_profiles
      final profile = await client
          .from('coach_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (profile == null) {
        state = SecurityGateState(
          status: SecurityGateStatus.pendingAdminApproval,
          email: user.email,
        );
        return;
      }

      final isSuspended = profile['is_suspended'] as bool? ?? false;
      final isApproved = profile['is_approved'] as bool? ?? false;
      final firstName = profile['first_name'] as String? ?? '';
      final lastName = profile['last_name'] as String? ?? '';
      final fullName = '$firstName $lastName'.trim();
      final lockReason = profile['lock_reason'] as String? ??
          'حساب شما توسط توسعه‌دهنده غیرفعال شده است.';

      await _secureStore.write(
          key: _kCachedSuspended, value: isSuspended ? 'true' : 'false');
      await _secureStore.write(
          key: _kCachedApproved, value: isApproved ? 'true' : 'false');
      await _secureStore.write(key: _kCachedLockMsg, value: lockReason);

      if (isSuspended) {
        state = SecurityGateState(
          status: SecurityGateStatus.suspendedKillSwitch,
          coachFullName: fullName,
          email: user.email,
          lockMessage: lockReason,
          developerContact: appControl?['developer_contact'] as String? ??
              'Developer Support',
        );
        return;
      }

      if (!isApproved) {
        state = SecurityGateState(
          status: SecurityGateStatus.pendingAdminApproval,
          coachFullName: fullName,
          email: user.email,
        );
        return;
      }

      if (fullName.isNotEmpty) {
        final currentBrand = _ref.read(brandingProvider);
        if (currentBrand.coachName == 'مربی حرفه‌ای') {
          await _ref
              .read(brandingProvider.notifier)
              .updateBranding(currentBrand.copyWith(coachName: fullName));
        }
      }

      state = SecurityGateState(
        status: SecurityGateStatus.authorizedAndActive,
        coachFullName: fullName,
        email: user.email,
      );
    } catch (_) {
      await _evaluateOfflineSecurityFallback();
    }
  }

  Future<void> _evaluateOfflineSecurityFallback() async {
    final cachedSuspended = await _secureStore.read(key: _kCachedSuspended);
    final cachedApproved = await _secureStore.read(key: _kCachedApproved);
    final cachedMsg = await _secureStore.read(key: _kCachedLockMsg);
    final cachedContact = await _secureStore.read(key: _kCachedDevContact);
    final cachedAthleteCode =
        await _secureStore.read(key: _kCachedAthleteCode);

    if (cachedSuspended == 'true') {
      state = SecurityGateState(
        status: SecurityGateStatus.suspendedKillSwitch,
        lockMessage:
            cachedMsg ?? 'دسترسی شما توسط توسعه‌دهنده مسدود شده است.',
        developerContact: cachedContact ?? 'Developer Support',
      );
      return;
    }

    if (cachedAthleteCode != null && cachedAthleteCode.isNotEmpty) {
      final localAth = _ref
          .read(appDatabaseProvider)
          .getAthleteByAccessCode(cachedAthleteCode);
      if (localAth != null) {
        state = SecurityGateState(
          status: SecurityGateStatus.athletePortalActive,
          loggedInAthlete: localAth,
        );
        return;
      }
    }

    if (cachedApproved == 'true') {
      state = const SecurityGateState(
          status: SecurityGateStatus.authorizedAndActive);
      return;
    }

    state = const SecurityGateState(status: SecurityGateStatus.unauthenticated);
  }

  /// ورود ورزشکار با کد دعوت ۶ رقمی اختصاصی، شماره تماس یا ایمیل (آنلاین با RPC + پشتیبانی آفلاین)
  Future<void> signInAthleteByCode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    state = const SecurityGateState(status: SecurityGateStatus.loading);
    final db = _ref.read(appDatabaseProvider);

    try {
      if (!SupabaseConfig.isInitialized) {
        await SupabaseConfig.initializeSafely();
      }
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        final res = await client.rpc(
          'athlete_login_by_code',
          params: {'p_access_code': code},
        ).timeout(const Duration(seconds: 6));

        if (res != null && res is Map<String, dynamic>) {
          final athMap = res['athlete'] as Map<String, dynamic>;
          final progsList = res['programs'] as List<dynamic>? ?? [];

          final rawTags = athMap['injury_tags'];
          final List<String> tags = rawTags is String
              ? List<String>.from(jsonDecode(rawTags))
              : List<String>.from(rawTags ?? []);

          final athlete = AthleteEntity(
            id: athMap['id'] as String,
            firstName: athMap['first_name'] as String? ?? '',
            lastName: athMap['last_name'] as String? ?? '',
            phone: athMap['phone'] as String? ?? '',
            email: athMap['email'] as String? ?? '',
            accessCode: athMap['access_code'] as String? ?? code,
            gender: athMap['gender'] as String? ?? 'male',
            age: (athMap['age'] as num?)?.toInt() ?? 25,
            heightCm: (athMap['height_cm'] as num?)?.toDouble() ?? 175,
            weightKg: (athMap['weight_kg'] as num?)?.toDouble() ?? 75,
            fitnessGoal: athMap['fitness_goal'] as String? ?? 'lean_bulk',
            injuryTags: tags,
            createdAt: DateTime.parse(athMap['created_at'] as String).toLocal(),
            updatedAt: DateTime.parse(athMap['updated_at'] as String).toLocal(),
            syncStatus: 'synced',
          );
          db.upsertAthlete(athlete);

          for (final pRow in progsList) {
            if (pRow is! Map<String, dynamic>) continue;
            final rawDays = pRow['days_json'];
            final decodedDays =
                (rawDays is String ? jsonDecode(rawDays) : rawDays)
                    as List<dynamic>;
            final rawMeals = pRow['diet_meals_json'];
            final mealsStr =
                rawMeals is String ? rawMeals : jsonEncode(rawMeals);
            final rawSupps = pRow['supplements_json'];
            final suppsStr =
                rawSupps is String ? rawSupps : jsonEncode(rawSupps);

            db.upsertProgram(FullProgramEntity(
              id: pRow['id'] as String,
              athleteId: athlete.id,
              title: pRow['title'] as String? ?? '',
              startDate: DateTime.parse(pRow['start_date'] as String).toLocal(),
              durationWeeks: (pRow['duration_weeks'] as num?)?.toInt() ?? 4,
              days: decodedDays
                  .map((e) =>
                      WorkoutDayPlan.fromJson(e as Map<String, dynamic>))
                  .toList(),
              dietMeals: DietMealSlot.decodeList(mealsStr),
              waterLiters: (pRow['water_liters'] as num?)?.toDouble() ?? 3.5,
              supplements: SupplementPrescriptionItem.decodeList(suppsStr),
              updatedAt: DateTime.now(),
              syncStatus: 'synced',
            ));
          }

          final measList = res['measurements'] as List<dynamic>? ?? [];
          for (final mRow in measList) {
            if (mRow is! Map<String, dynamic>) continue;
            db.insertMeasurementLog(MeasurementLogEntity(
              id: mRow['id'] as String,
              athleteId: athlete.id,
              recordedAt:
                  DateTime.parse(mRow['recorded_at'] as String).toLocal(),
              weightKg: (mRow['weight_kg'] as num).toDouble(),
              bodyFatPercent: (mRow['body_fat_percent'] as num?)?.toDouble(),
              shoulderCm: (mRow['shoulder_cm'] as num?)?.toDouble(),
              chestCm: (mRow['chest_cm'] as num?)?.toDouble(),
              waistCm: (mRow['waist_cm'] as num?)?.toDouble(),
              hipsCm: (mRow['hips_cm'] as num?)?.toDouble(),
              bicepsCm: (mRow['biceps_cm'] as num?)?.toDouble(),
              forearmCm: (mRow['forearm_cm'] as num?)?.toDouble(),
              thighCm: (mRow['thigh_cm'] as num?)?.toDouble(),
              calfCm: (mRow['calf_cm'] as num?)?.toDouble(),
              updatedAt: DateTime.now(),
              syncStatus: 'synced',
            ));
          }

          await _secureStore.write(
              key: _kCachedAthleteCode, value: athlete.accessCode);
          state = SecurityGateState(
            status: SecurityGateStatus.athletePortalActive,
            loggedInAthlete: athlete,
          );
          return;
        }
      }
    } catch (_) {}

    // بررسی دیتابیس محلی در صورت آفلاین بودن
    final localAthlete = db.getAthleteByAccessCode(code);
    if (localAthlete != null) {
      await _secureStore.write(
          key: _kCachedAthleteCode, value: localAthlete.accessCode);
      state = SecurityGateState(
        status: SecurityGateStatus.athletePortalActive,
        loggedInAthlete: localAthlete,
      );
      return;
    }

    state = const SecurityGateState(
      status: SecurityGateStatus.unauthenticated,
      errorMessage:
          'کد ورود ورزشکار یافت نشد. لطفاً کد ۶ رقمی (مثلاً PC-XXXXXX) را از مربی خود دریافت کنید.',
    );
  }

  Future<void> signUpCoach({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = const SecurityGateState(status: SecurityGateStatus.loading);
    try {
      if (!SupabaseConfig.isInitialized) {
        await SupabaseConfig.initializeSafely();
      }
      final client = SupabaseConfig.clientOrNull;
      if (client == null) {
        state = const SecurityGateState(
          status: SecurityGateStatus.unauthenticated,
          errorMessage: 'برای ثبت‌نام اولیه، اتصال به اینترنت الزامی است.',
        );
        return;
      }

      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        },
      );

      if (res.user != null) {
        await _secureStore.write(key: _kCachedApproved, value: 'false');
        state = SecurityGateState(
          status: SecurityGateStatus.pendingAdminApproval,
          coachFullName: '$firstName $lastName',
          email: email.trim(),
        );
      }
    } on AuthException catch (e) {
      state = SecurityGateState(
        status: SecurityGateStatus.unauthenticated,
        errorMessage: e.message,
      );
    } catch (_) {
      state = const SecurityGateState(
        status: SecurityGateStatus.unauthenticated,
        errorMessage: 'خطا در ثبت‌نام: لطفاً اتصال اینترنت را بررسی کنید.',
      );
    }
  }

  Future<void> signInCoach({
    required String email,
    required String password,
  }) async {
    state = const SecurityGateState(status: SecurityGateStatus.loading);
    try {
      if (!SupabaseConfig.isInitialized) {
        await SupabaseConfig.initializeSafely();
      }
      final client = SupabaseConfig.clientOrNull;
      if (client == null) {
        state = const SecurityGateState(
          status: SecurityGateStatus.unauthenticated,
          errorMessage: 'برای ورود به حساب، اتصال اینترنت را روشن کنید.',
        );
        return;
      }

      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      await verifySecurityAndSession();
    } on AuthException catch (e) {
      state = SecurityGateState(
        status: SecurityGateStatus.unauthenticated,
        errorMessage: e.message,
      );
    } catch (_) {
      state = const SecurityGateState(
        status: SecurityGateStatus.unauthenticated,
        errorMessage: 'ایمیل یا رمز عبور اشتباه است یا اینترنت متصل نیست.',
      );
    }
  }

  Future<void> signOut() async {
    _appControlRealtimeSub?.cancel();
    _coachProfileRealtimeSub?.cancel();
    try {
      await SupabaseConfig.clientOrNull?.auth.signOut();
    } catch (_) {}
    await _secureStore.deleteAll();
    try {
      _ref.read(appDatabaseProvider).clearAllUserDataOnLogout();
    } catch (_) {}
    state = const SecurityGateState(status: SecurityGateStatus.unauthenticated);
  }
}

/// ویجت دروازه امنیتی + محافظ مخفیسازی صفحه در Recent Apps اندروید/iOS (رفع عیب ۵ گزارش ممیزی)
class SecurityGateWrapper extends ConsumerStatefulWidget {
  final Widget authorizedChild;
  const SecurityGateWrapper({super.key, required this.authorizedChild});

  @override
  ConsumerState<SecurityGateWrapper> createState() =>
      _SecurityGateWrapperState();
}

class _SecurityGateWrapperState extends ConsumerState<SecurityGateWrapper>
    with WidgetsBindingObserver {
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isInBackground = state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(securityGateProvider);

    Widget activeScreen;
    switch (gate.status) {
      case SecurityGateStatus.loading:
        activeScreen = const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
        break;
      case SecurityGateStatus.unauthenticated:
        activeScreen = CoachAuthScreen(errorMessage: gate.errorMessage);
        break;
      case SecurityGateStatus.pendingAdminApproval:
        activeScreen = PendingApprovalScreen(
          coachName: gate.coachFullName ?? '',
          email: gate.email ?? '',
        );
        break;
      case SecurityGateStatus.suspendedKillSwitch:
        activeScreen = AppSuspendedKillSwitchScreen(
          title: gate.lockTitle,
          message: gate.lockMessage,
          developerContact: gate.developerContact,
        );
        break;
      case SecurityGateStatus.athletePortalActive:
        activeScreen = AthletePortalScreen(
          key: ValueKey(gate.loggedInAthlete!.id),
          initialAthlete: gate.loggedInAthlete!,
        );
        break;
      case SecurityGateStatus.authorizedAndActive:
        activeScreen = widget.authorizedChild;
        break;
    }

    return Stack(
      children: [
        activeScreen,
        // لایه امنیتی ضد اسکرین‌شات در پنجره برنامه‌های اخیر سیستم‌عامل (OWASP Privacy Shield)
        if (_isInBackground)
          Positioned.fill(
            child: Container(
              color: AppColors.darkBg,
              alignment: Alignment.center,
              child: const Icon(LucideIcons.shieldCheck,
                  size: 64, color: Colors.white24),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// صفحه ورود دوگانه: تب ۱ (مربی) | تب ۲ (ورزشکار با کد اختصاصی)
// =============================================================================
class CoachAuthScreen extends ConsumerStatefulWidget {
  final String? errorMessage;
  const CoachAuthScreen({super.key, this.errorMessage});

  @override
  ConsumerState<CoachAuthScreen> createState() => _CoachAuthScreenState();
}

class _CoachAuthScreenState extends ConsumerState<CoachAuthScreen> {
  bool _isAthleteMode = false; // false = مربی | true = ورزشکار
  bool _isLogin = true;
  bool _obscurePass = true;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _athleteCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _athleteCodeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final isFa = AppStrings.of(context).isFa;

    if (_isAthleteMode) {
      final code = _athleteCodeCtrl.text.trim();
      if (code.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFa
                ? 'لطفاً کد اختصاصی، شماره موبایل یا ایمیل ورزشکار را وارد کنید.'
                : 'Please enter your athlete access code, phone or email.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      ref.read(securityGateProvider.notifier).signInAthleteByCode(code);
      return;
    }

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    if (!email.contains('@') || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFa
              ? 'لطفاً یک ایمیل معتبر و رمز عبور حداقل ۶ کاراکتری وارد کنید.'
              : 'Enter a valid email and at least 6-character password.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_isLogin) {
      ref
          .read(securityGateProvider.notifier)
          .signInCoach(email: email, password: pass);
    } else {
      if (_firstNameCtrl.text.trim().isEmpty ||
          _lastNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFa
                ? 'وارد کردن نام و نام خانوادگی مربی الزامی است.'
                : 'First name and Last name are required.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      ref.read(securityGateProvider.notifier).signUpCoach(
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            email: email,
            password: pass,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // سوییچر دوگانه: مربی / ورزشکار
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(LucideIcons.shieldCheck, size: 16),
                          label: Text(isFa ? 'پنل مربی' : 'Coach Mode'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(LucideIcons.dumbbell, size: 16),
                          label: Text(isFa ? 'پنل ورزشکار' : 'Athlete Mode'),
                        ),
                      ],
                      selected: {_isAthleteMode},
                      onSelectionChanged: (s) =>
                          setState(() => _isAthleteMode = s.first),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isAthleteMode
                          ? (isFa
                              ? 'ورود ورزشکار به برنامه آنلاین'
                              : 'Athlete Portal Login')
                          : (_isLogin
                              ? (isFa
                                  ? 'ورود امن مربی به سامانه'
                                  : 'Secure Coach Sign-In')
                              : (isFa
                                  ? 'ثبت‌نام مربی جدید'
                                  : 'New Coach Registration')),
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (widget.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.errorMessage!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isAthleteMode) ...[
                      TextField(
                        controller: _athleteCodeCtrl,
                        textCapitalization: TextCapitalization.none,
                        decoration: InputDecoration(
                          labelText: isFa
                              ? 'کد اختصاصی (PC-XXXXXX)، شماره موبایل یا ایمیل ورزشکار'
                              : 'Access Code (PC-XXXXXX), Phone or Email',
                          prefixIcon: const Icon(LucideIcons.keyRound),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(LucideIcons.arrowRightCircle),
                          label: Text(isFa
                              ? 'مشاهده برنامه و چت با مربی'
                              : 'Enter Athlete Portal'),
                        ),
                      ),
                    ] else ...[
                      if (!_isLogin) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _firstNameCtrl,
                                decoration: InputDecoration(
                                  labelText: isFa ? 'نام *' : 'First Name *',
                                  prefixIcon: const Icon(LucideIcons.user),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _lastNameCtrl,
                                decoration: InputDecoration(
                                  labelText:
                                      isFa ? 'نام خانوادگی *' : 'Last Name *',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: isFa ? 'ایمیل مربی' : 'Email Address',
                          prefixIcon: const Icon(LucideIcons.mail),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePass,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: isFa ? 'رمز عبور' : 'Password',
                          prefixIcon: const Icon(LucideIcons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: Icon(_isLogin
                              ? LucideIcons.logIn
                              : LucideIcons.userPlus),
                          label: Text(_isLogin
                              ? (isFa ? 'ورود به اپلیکیشن' : 'Sign In')
                              : (isFa
                                  ? 'ثبت‌نام و ارسال درخواست تایید'
                                  : 'Register & Request Approval')),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin
                              ? (isFa
                                  ? 'حساب کاربری ندارید؟ ثبت‌نام مربی جدید'
                                  : 'Don\'t have an account? Register')
                              : (isFa
                                  ? 'قبلاً ثبت‌نام کرده‌اید؟ ورود به حساب'
                                  : 'Already registered? Sign In'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PendingApprovalScreen extends ConsumerWidget {
  final String coachName;
  final String email;

  const PendingApprovalScreen({
    super.key,
    required this.coachName,
    required this.email,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFa = AppStrings.of(context).isFa;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.clock,
                      size: 56, color: AppColors.warning),
                  const SizedBox(height: 16),
                  Text(
                    isFa
                        ? 'حساب شما در انتظار تایید مدیر است'
                        : 'Account Pending Admin Approval',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isFa
                        ? 'مربی گرامی ($coachName - $email)، ثبت‌نام شما با موفقیت انجام شد. پس از تایید دسترسی شما توسط توسعه‌دهنده در پنل مدیریت، روی دکمه زیر بزنید.'
                        : 'Your registration ($email) is complete. Once approved by the administrator, tap Refresh below.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(securityGateProvider.notifier)
                        .verifySecurityAndSession(),
                    icon: const Icon(LucideIcons.refreshCw),
                    label: Text(isFa
                        ? 'بررسی وضعیت تایید حساب'
                        : 'Check Approval Status'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(securityGateProvider.notifier).signOut(),
                    icon: const Icon(LucideIcons.logOut, size: 16),
                    label: Text(isFa ? 'خروج از حساب' : 'Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSuspendedKillSwitchScreen extends ConsumerWidget {
  final String title;
  final String message;
  final String developerContact;

  const AppSuspendedKillSwitchScreen({
    super.key,
    required this.title,
    required this.message,
    required this.developerContact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFa = AppStrings.of(context).isFa;

    return Scaffold(
      backgroundColor: const Color(0xFF140C0E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: const Color(0xFF221417),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.danger, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.shieldAlert,
                      size: 64, color: AppColors.danger),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.headphones,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            developerContact,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(securityGateProvider.notifier)
                        .verifySecurityAndSession(),
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: Text(isFa
                        ? 'بررسی مجدد وضعیت لایسنس'
                        : 'Re-verify License Status'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
