import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'branding_model.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main.dart');
});

final brandingProvider =
    StateNotifierProvider<BrandingNotifier, BrandingConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BrandingNotifier(prefs);
});

class BrandingNotifier extends StateNotifier<BrandingConfig> {
  final SharedPreferences _prefs;

  BrandingNotifier(this._prefs) : super(const BrandingConfig()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final isDark = _prefs.getBool('is_dark') ?? true;
    final langCode = _prefs.getString('lang_code') ?? 'fa';

    state = BrandingConfig(
      coachName: _prefs.getString('coach_name') ?? 'مربی حرفهای',
      coachCredentials: _prefs.getString('coach_credentials') ??
          'مربی رسمی فدراسیون بدنسازی و متخصص تغذیه ورزشی',
      gymName: _prefs.getString('gym_name') ?? 'آکادمی تخصصی فیتنس پرو',
      socialHandle: _prefs.getString('social_handle') ?? '@pro_coach_fitness',
      logoPath: _prefs.getString('logo_path'),
      colorPresetId: _prefs.getString('color_preset_id') ?? 'neon_volt',
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(langCode),
      defaultTuitionFee: _prefs.getDouble('tuition_fee') ?? 800000,
      defaultWorkoutFee: _prefs.getDouble('workout_fee') ?? 500000,
      defaultDietFee: _prefs.getDouble('diet_fee') ?? 400000,
      defaultSupplementFee: _prefs.getDouble('supplement_fee') ?? 200000,
    );
  }

  Future<void> updateBranding(BrandingConfig newConfig) async {
    state = newConfig;
    await _prefs.setString('coach_name', newConfig.coachName);
    await _prefs.setString('coach_credentials', newConfig.coachCredentials);
    await _prefs.setString('gym_name', newConfig.gymName);
    await _prefs.setString('social_handle', newConfig.socialHandle);
    if (newConfig.logoPath != null) {
      await _prefs.setString('logo_path', newConfig.logoPath!);
    } else {
      await _prefs.remove('logo_path');
    }
    await _prefs.setString('color_preset_id', newConfig.colorPresetId);
    await _prefs.setBool('is_dark', newConfig.themeMode == ThemeMode.dark);
    await _prefs.setString('lang_code', newConfig.locale.languageCode);
    await _prefs.setDouble('tuition_fee', newConfig.defaultTuitionFee);
    await _prefs.setDouble('workout_fee', newConfig.defaultWorkoutFee);
    await _prefs.setDouble('diet_fee', newConfig.defaultDietFee);
    await _prefs.setDouble('supplement_fee', newConfig.defaultSupplementFee);
  }

  void toggleThemeMode() {
    final newMode =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    updateBranding(state.copyWith(themeMode: newMode));
  }

  void toggleLanguage() {
    final newLocale = state.locale.languageCode == 'fa'
        ? const Locale('en')
        : const Locale('fa');
    updateBranding(state.copyWith(locale: newLocale));
  }

  void setColorPreset(String presetId) {
    updateBranding(state.copyWith(colorPresetId: presetId));
  }
}
