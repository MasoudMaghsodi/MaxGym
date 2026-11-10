import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BrandingConfig {
  final String coachName;
  final String coachCredentials;
  final String gymName;
  final String socialHandle;
  final String? logoPath;
  final String colorPresetId;
  final int? customPrimaryColorHex; // امکان انتخاب رنگ کاملاً دلخواه توسط مربی
  final ThemeMode themeMode;
  final Locale locale;

  final double defaultTuitionFee;
  final double defaultWorkoutFee;
  final double defaultDietFee;
  final double defaultSupplementFee;

  const BrandingConfig({
    this.coachName = 'مربی ارشد مکسجیم',
    this.coachCredentials = 'مربی رسمی بدنسازی و متخصص تغذیه ورزشی | MAX GYM',
    this.gymName = 'باشگاه تخصصی MAX GYM',
    this.socialHandle = '@maxgym_official',
    this.logoPath,
    this.colorPresetId = 'maxgym_venom', // پیشفرض: سبز رسمی باشگاه مکس
    this.customPrimaryColorHex,
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
    int? customPrimaryColorHex,
    bool clearCustomColor = false,
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
      customPrimaryColorHex: clearCustomColor
          ? null
          : (customPrimaryColorHex ?? this.customPrimaryColorHex),
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      defaultTuitionFee: defaultTuitionFee ?? this.defaultTuitionFee,
      defaultWorkoutFee: defaultWorkoutFee ?? this.defaultWorkoutFee,
      defaultDietFee: defaultDietFee ?? this.defaultDietFee,
      defaultSupplementFee: defaultSupplementFee ?? this.defaultSupplementFee,
    );
  }
}
