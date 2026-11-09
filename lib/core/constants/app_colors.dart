import 'package:flutter/material.dart';

class BrandColorPreset {
  final String id;
  final String nameFa;
  final String nameEn;
  final Color primary;
  final Color secondary;

  const BrandColorPreset({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.primary,
    required this.secondary,
  });
}

class AppColors {
  // رنگهای پسزمینه استاندارد Dark Mode باشگاهی
  static const Color darkBg = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF181B22);
  static const Color darkCard = Color(0xFF222630);

  // رنگهای پسزمینه استاندارد Light Mode
  static const Color lightBg = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEEF1F6);

  // وضعیتها (هشدار انقضای برنامه، بدهی مالی، آسیبدیدگی)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  /// لیست پالتهای رنگی قابل انتخاب توسط مربی (برای UI و PDF)
  static const List<BrandColorPreset> presets = [
    BrandColorPreset(
      id: 'neon_volt',
      nameFa: 'سبز نئونی (Volt)',
      nameEn: 'Neon Volt',
      primary: Color(0xFFB4F000),
      secondary: Color(0xFF8BC34A),
    ),
    BrandColorPreset(
      id: 'energy_orange',
      nameFa: 'نارنجی انرژی',
      nameEn: 'Energy Orange',
      primary: Color(0xFFFF6B00),
      secondary: Color(0xFFFF9E44),
    ),
    BrandColorPreset(
      id: 'electric_blue',
      nameFa: 'آبی الکتریک',
      nameEn: 'Electric Blue',
      primary: Color(0xFF00E5FF),
      secondary: Color(0xFF0091EA),
    ),
    BrandColorPreset(
      id: 'vip_gold',
      nameFa: 'طلایی (VIP)',
      nameEn: 'VIP Gold',
      primary: Color(0xFFFFD700),
      secondary: Color(0xFFDAA520),
    ),
    BrandColorPreset(
      id: 'crimson_power',
      nameFa: 'قرمز پاورلیفتینگ',
      nameEn: 'Crimson Power',
      primary: Color(0xFFFF2A54),
      secondary: Color(0xFFD50000),
    ),
  ];

  static BrandColorPreset getPresetById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }
}
