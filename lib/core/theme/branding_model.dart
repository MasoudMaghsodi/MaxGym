import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BrandingConfig {
  final String coachName;
  final String coachCredentials;
  final String gymName;
  final String socialHandle;
  final String? logoPath; // مسیر فایل لوگوی انتخابی از گالری گوشی
  final String colorPresetId;
  final ThemeMode themeMode;
  final Locale locale;

  // تعرفههای پایه مالی برای سرعت بخشیدن به صدور فاکتور شاگرد
  final double defaultTuitionFee;
  final double defaultWorkoutFee;
  final double defaultDietFee;
  final double defaultSupplementFee;

  const BrandingConfig({
    this.coachName = 'مربی حرفهای',
    this.coachCredentials = 'مربی رسمی فدراسیون بدنسازی و متخصص تغذیه ورزشی',
    this.gymName = 'آکادمی تخصصی فیتنس پرو',
    this.socialHandle = '@pro_coach_fitness',
    this.logoPath,
    this.colorPresetId = 'neon_volt',
    this.themeMode = ThemeMode.dark,
    this.locale = const Locale('fa'),
    this.defaultTuitionFee = 800000,
    this.defaultWorkoutFee = 500000,
    this.defaultDietFee = 400000,
    this.defaultSupplementFee = 200000,
  });

  BrandColorPreset get activePreset => AppColors.getPresetById(colorPresetId);

  BrandingConfig copyWith({
    String? coachName,
    String? coachCredentials,
    String? gymName,
    String? socialHandle,
    String? logoPath,
    bool clearLogo = false,
    String? colorPresetId,
    ThemeMode? themeMode,
    Locale? locale,
    double? defaultTuitionFee,
    double? defaultWorkoutFee,
    double? defaultDietFee,
    double? defaultSupplementFee,
  }) {
    return BrandingConfig(
      coachName: coachName ?? this.coachName,
      coachCredentials: coachCredentials ?? this.coachCredentials,
      gymName: gymName ?? this.gymName,
      socialHandle: socialHandle ?? this.socialHandle,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      colorPresetId: colorPresetId ?? this.colorPresetId,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      defaultTuitionFee: defaultTuitionFee ?? this.defaultTuitionFee,
      defaultWorkoutFee: defaultWorkoutFee ?? this.defaultWorkoutFee,
      defaultDietFee: defaultDietFee ?? this.defaultDietFee,
      defaultSupplementFee: defaultSupplementFee ?? this.defaultSupplementFee,
    );
  }
}
