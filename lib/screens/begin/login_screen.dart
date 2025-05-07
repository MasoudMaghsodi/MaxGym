import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:max_gym/main.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:vibration/vibration.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      Vibration.vibrate(duration: 200);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('login_error')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF212121), Color(0xFFE53935)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  child: AnimationLimiter(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 600),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          verticalOffset: 50.h,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: [
                          Image.asset(
                            'assets/images/max.png',
                            width: 150.w,
                            height: 150.h,
                            fit: BoxFit.contain,
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.5),
                            colorBlendMode: BlendMode.overlay,
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            l10n.translate('login_title'),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            l10n.translate('login_subtitle'),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16.sp,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          _buildTextField(
                            controller: _emailController,
                            label: l10n.translate('email'),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _passwordController,
                            label: l10n.translate('password'),
                            icon: Icons.lock_outlined,
                            obscureText: !_isPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          SizedBox(height: 24.h),
                          _buildLoginButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16.h,
                right: 16.w,
                child: _buildSettingsButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16.sp,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white70,
            fontSize: 14.sp,
          ),
          prefixIcon: Icon(icon, color: Colors.white70, size: 20.sp),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 48.h),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                l10n.translate('login_button'),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSettingsButtons() {
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;

    return Row(
      children: [
        _buildIconButton(
          icon: isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
          onPressed: () {
            // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
            ref.read(themeProvider.notifier).state =
                isDarkMode ? ThemeMode.light : ThemeMode.dark;
          },
          tooltip: isDarkMode
              ? l10n.translate('switch_to_light')
              : l10n.translate('switch_to_dark'),
        ),
        SizedBox(width: 8.w),
        _buildIconButton(
          icon: Icons.language,
          onPressed: () {
            final currentLocale = ref.read(localeProvider);
            ref.read(localeProvider.notifier).state =
                currentLocale.languageCode == 'fa'
                    ? const Locale('en', 'US')
                    : const Locale('fa', 'IR');
          },
          tooltip: l10n.translate('switch_language'),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.2),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24.sp,
          ),
        ),
      ),
    );
  }
}
