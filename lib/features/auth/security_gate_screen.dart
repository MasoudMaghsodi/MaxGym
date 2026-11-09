import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/branding_provider.dart';

enum SecurityGateStatus {
  loading,
  unauthenticated,
  pendingAdminApproval,
  suspendedKillSwitch,
  authorizedAndActive,
}

class SecurityGateState {
  final SecurityGateStatus status;
  final String? coachFullName;
  final String? email;
  final String lockTitle;
  final String lockMessage;
  final String developerContact;
  final String? errorMessage;

  const SecurityGateState({
    required this.status,
    this.coachFullName,
    this.email,
    this.lockTitle = 'دسترسی به اپلیکیشن مسدود شده است',
    this.lockMessage =
        'به علت عدم تسویه حساب یا نقض قوانین، دسترسی شما توسط توسعهدهنده غیرفعال شده است.',
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

  // کلیدهای رمزنگاریشده برای جلوگیری از دور زدن Kill-Switch با حالت پرواز (Airplane Mode)
  static const _kCachedApproved = 'sec_cached_is_approved';
  static const _kCachedSuspended = 'sec_cached_is_suspended';
  static const _kCachedLockMsg = 'sec_cached_lock_msg';
  static const _kCachedDevContact = 'sec_cached_dev_contact';

  SecurityGateNotifier(this._ref)
      : super(const SecurityGateState(status: SecurityGateStatus.loading)) {
    verifySecurityAndSession();
  }

  /// بررسی چندلایه وضعیت قفل سراسری، توکن احراز هویت و تایید ادمین
  Future<void> verifySecurityAndSession() async {
    state = const SecurityGateState(status: SecurityGateStatus.loading);

    if (!SupabaseConfig.isInitialized) {
      await SupabaseConfig.initializeSafely();
    }
    final client = SupabaseConfig.clientOrNull;

    // ۱. اگر اینترنت قطع است، از وضعیت امنیتی رمزنگاریشده در Keystore استفاده کن
    if (client == null) {
      await _evaluateOfflineSecurityFallback();
      return;
    }

    try {
      // ۲. بررسی سوئیچ مرگ سراسری اپلیکیشن (Global Kill-Switch در جدول app_control)
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
            'لطفاً با توسعهدهنده تماس بگیرید.';
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

      // ۳. بررسی وجود نشست معتبر (JWT Session)
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (session == null || user == null) {
        state = const SecurityGateState(
            status: SecurityGateStatus.unauthenticated);
        return;
      }

      // ۴. بررسی پروفایل مربی در جدول coach_profiles (تایید ادمین و مسدودیت تکی)
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
          'حساب شما توسط توسعهدهنده غیرفعال شده است.';

      // ذخیره در حافظه رمزنگاریشده برای حالت آفلاین
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

      // ۵. اگر مربی تایید شده و فعال است، نامش را در تنظیمات برندینگ همگام کن و اجازه ورود بده
      if (fullName.isNotEmpty) {
        final currentBrand = _ref.read(brandingProvider);
        if (currentBrand.coachName == 'مربی حرفهای') {
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
      // اگر در باشگاه اینترنت قطع یا ضعیف بود، از کش رمزنگاریشده بررسی کن
      await _evaluateOfflineSecurityFallback();
    }
  }

  Future<void> _evaluateOfflineSecurityFallback() async {
    final cachedSuspended = await _secureStore.read(key: _kCachedSuspended);
    final cachedApproved = await _secureStore.read(key: _kCachedApproved);
    final cachedMsg = await _secureStore.read(key: _kCachedLockMsg);
    final cachedContact = await _secureStore.read(key: _kCachedDevContact);

    if (cachedSuspended == 'true') {
      state = SecurityGateState(
        status: SecurityGateStatus.suspendedKillSwitch,
        lockMessage:
            cachedMsg ?? 'دسترسی شما توسط توسعهدهنده مسدود شده است.',
        developerContact: cachedContact ?? 'Developer Support',
      );
      return;
    }

    if (cachedApproved == 'true') {
      state = const SecurityGateState(
          status: SecurityGateStatus.authorizedAndActive);
      return;
    }

    state = const SecurityGateState(status: SecurityGateStatus.unauthenticated);
  }

  /// ثبتنام مربی جدید با نام، نام خانوادگی، ایمیل و رمز عبور
  Future<void> signUpCoach({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = const SecurityGateState(status: SecurityGateStatus.loading);
    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null) {
        state = const SecurityGateState(
          status: SecurityGateStatus.unauthenticated,
          errorMessage: 'برای ثبتنام اولیه، اتصال به اینترنت الزامی است.',
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
        // اطمینان از درج رکورد در coach_profiles
        try {
          await client.from('coach_profiles').upsert({
            'id': res.user!.id,
            'email': email.trim(),
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'is_approved': false,
            'is_suspended': false,
          });
        } catch (_) {}

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
    } catch (e) {
      state = const SecurityGateState(
        status: SecurityGateStatus.unauthenticated,
        errorMessage: 'خطا در ثبتنام: لطفاً اتصال اینترنت را بررسی کنید.',
      );
    }
  }

  /// ورود مربی با ایمیل و رمز عبور
  Future<void> signInCoach({
    required String email,
    required String password,
  }) async {
    state = const SecurityGateState(status: SecurityGateStatus.loading);
    try {
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

  /// خروج امن و پاکسازی کامل کلیدهای رمزنگاریشده
  Future<void> signOut() async {
    try {
      await SupabaseConfig.clientOrNull?.auth.signOut();
    } catch (_) {}
    await _secureStore.deleteAll();
    state = const SecurityGateState(status: SecurityGateStatus.unauthenticated);
  }
}

/// ویجت دروازه امنیتی که دور کل اپلیکیشن قرار میگیرد
class SecurityGateWrapper extends ConsumerWidget {
  final Widget authorizedChild;
  const SecurityGateWrapper({super.key, required this.authorizedChild});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(securityGateProvider);

    switch (gate.status) {
      case SecurityGateStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case SecurityGateStatus.unauthenticated:
        return CoachAuthScreen(errorMessage: gate.errorMessage);
      case SecurityGateStatus.pendingAdminApproval:
        return PendingApprovalScreen(
          coachName: gate.coachFullName ?? '',
          email: gate.email ?? '',
        );
      case SecurityGateStatus.suspendedKillSwitch:
        return AppSuspendedKillSwitchScreen(
          title: gate.lockTitle,
          message: gate.lockMessage,
          developerContact: gate.developerContact,
        );
      case SecurityGateStatus.authorizedAndActive:
        return authorizedChild;
    }
  }
}

// =============================================================================
// ۱. صفحه لاگین و ثبتنام امن مربی (Login / Sign-Up Screen)
// =============================================================================
class CoachAuthScreen extends ConsumerStatefulWidget {
  final String? errorMessage;
  const CoachAuthScreen({super.key, this.errorMessage});

  @override
  ConsumerState<CoachAuthScreen> createState() => _CoachAuthScreenState();
}

class _CoachAuthScreenState extends ConsumerState<CoachAuthScreen> {
  bool _isLogin = true;
  bool _obscurePass = true;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final isFa = AppStrings.of(context).isFa;
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
    final theme = Theme.of(context);

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
                    CircleAvatar(
                      radius: 34,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.15),
                      child: Icon(LucideIcons.shieldCheck,
                          size: 34, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin
                          ? (isFa
                              ? 'ورود امن مربی به سامانه'
                              : 'Secure Coach Sign-In')
                          : (isFa
                              ? 'ثبتنام مربی جدید'
                              : 'New Coach Registration'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? (isFa
                              ? 'اطلاعات حساب تاییدشده خود را وارد کنید'
                              : 'Enter your approved credentials')
                          : (isFa
                              ? 'پس از ثبتنام، حساب شما باید توسط ادمین تایید شود'
                              : 'Requires admin approval after registration'),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
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
                                ? 'ثبتنام و ارسال درخواست تایید'
                                : 'Register & Request Approval')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? (isFa
                                ? 'حساب کاربری ندارید؟ ثبتنام مربی جدید'
                                : 'Don\'t have an account? Register')
                            : (isFa
                                ? 'قبلاً ثبتنام کردهاید؟ ورود به حساب'
                                : 'Already registered? Sign In'),
                      ),
                    ),
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

// =============================================================================
// ۲. صفحه انتظار برای تایید توسط شما در پنل سوپابیس (Pending Approval Screen)
// =============================================================================
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
                        ? 'مربی گرامی ($coachName - $email)، ثبتنام شما با موفقیت انجام شد. پس از تایید دسترسی شما توسط توسعهدهنده در پنل مدیریت، روی دکمه زیر بزنید.'
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

// =============================================================================
// ۳. صفحه قفل کامل اپلیکیشن توسط شما از پنل سوپابیس (Kill-Switch Screen)
// =============================================================================
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
