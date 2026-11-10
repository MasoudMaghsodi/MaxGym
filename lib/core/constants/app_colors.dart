import 'package:flutter/material.dart';

class BrandColorPreset {
  final String id;
  final String nameFa;
  final String nameEn;
  final Color darkPrimary;  // رنگ درخشان روی پسزمینه مشکی (Dark Mode)
  final Color lightPrimary; // رنگ عمیق و خوانا روی پسزمینه سفید (Light Mode)
  final Color secondary;

  const BrandColorPreset({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.darkPrimary,
    required this.lightPrimary,
    required this.secondary,
  });

  /// سازگاری با کدهای قبلی (بهصورت پیشفرض رنگ اصلی را برمیگرداند)
  Color get primary => darkPrimary;
}

class AppColors {
  // پسزمینههای لوکس Dark Mode (مشکی کربنی باشگاه مکس با تهرنگ یشمی نامحسوس)
  static const Color darkBg = Color(0xFF0B0E0C);
  static const Color darkSurface = Color(0xFF131715);
  static const Color darkCard = Color(0xFF1B211E);

  // پسزمینههای لوکس Light Mode (سفید تیتانیومی با کنتراست بالا برای خوانایی کامل متنها)
  static const Color lightBg = Color(0xFFF3F6F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);

  // رنگهای وضعیت
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  /// استودیوی گسترده پالتهای رنگی (پالت اول: تم رسمی لوگوی باشگاه MAX GYM)
  static const List<BrandColorPreset> presets = [
    BrandColorPreset(
      id: 'maxgym_venom',
      nameFa: 'سبز رسمی مکسجیم (MAX GYM Official)',
      nameEn: 'MAX GYM Official Green',
      darkPrimary: Color(0xFF72C832),  // سبز دقیق لوگوی MAX GYM روی مشکی
      lightPrimary: Color(0xFF2E7D32), // سبز جنگلی تیره و لوکس روی سفید (خوانایی ۱۰۰٪)
      secondary: Color(0xFFA3E635),
    ),
    BrandColorPreset(
      id: 'emerald_luxury',
      nameFa: 'سبز زمردی لوکس (Emerald VIP)',
      nameEn: 'Emerald Luxury',
      darkPrimary: Color(0xFF00E676),
      lightPrimary: Color(0xFF047857),
      secondary: Color(0xFF69F0AE),
    ),
    BrandColorPreset(
      id: 'neon_volt',
      nameFa: 'سبز فسفری نئون (Neon Volt)',
      nameEn: 'Neon Volt',
      darkPrimary: Color(0xFFB4F000),
      lightPrimary: Color(0xFF558B2F),
      secondary: Color(0xFF8BC34A),
    ),
    BrandColorPreset(
      id: 'vip_gold',
      nameFa: 'طلایی سلطنتی (Olympia Gold)',
      nameEn: 'Olympia Gold',
      darkPrimary: Color(0xFFFFD700),
      lightPrimary: Color(0xFFB45309),
      secondary: Color(0xFFDAA520),
    ),
    BrandColorPreset(
      id: 'energy_orange',
      nameFa: 'نارنجی آدرنالین (Adrenaline Orange)',
      nameEn: 'Adrenaline Orange',
      darkPrimary: Color(0xFFFF6B00),
      lightPrimary: Color(0xFFC2410C),
      secondary: Color(0xFFFF9E44),
    ),
    BrandColorPreset(
      id: 'crimson_power',
      nameFa: 'قرمز پاورلیفتینگ (Crimson Power)',
      nameEn: 'Crimson Power',
      darkPrimary: Color(0xFFFF2A54),
      lightPrimary: Color(0xFFB91C1C),
      secondary: Color(0xFFD50000),
    ),
    BrandColorPreset(
      id: 'electric_blue',
      nameFa: 'آبی الکتریک (Cyber Cyan)',
      nameEn: 'Electric Blue',
      darkPrimary: Color(0xFF00E5FF),
      lightPrimary: Color(0xFF0369A1),
      secondary: Color(0xFF0091EA),
    ),
    BrandColorPreset(
      id: 'royal_purple',
      nameFa: 'بنفش نیترو (Nitro Purple)',
      nameEn: 'Nitro Purple',
      darkPrimary: Color(0xFFC084FC),
      lightPrimary: Color(0xFF6D28D9),
      secondary: Color(0xFF9333EA),
    ),
    BrandColorPreset(
      id: 'titanium_monochrome',
      nameFa: 'تیتانیوم مونوکروم (مشکی و سفید خالص)',
      nameEn: 'Titanium Monochrome',
      darkPrimary: Color(0xFFE2E8F0),
      lightPrimary: Color(0xFF0F172A),
      secondary: Color(0xFF94A3B8),
    ),
  ];

  static BrandColorPreset getPresetById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }
}
