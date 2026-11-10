import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'branding_model.dart';

class AppTheme {
  static ThemeData buildTheme(BrandingConfig config, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final preset = config.activePreset;

    // انتخاب هوشمند رنگ: در حالت تاریک از رنگ نئونی درخشان و در حالت روشن از رنگ عمیق با کنتراست بالا استفاده میشود
    final Color effectivePrimary;
    if (config.customPrimaryColorHex != null) {
      effectivePrimary = Color(config.customPrimaryColorHex!);
    } else {
      effectivePrimary = isDark ? preset.darkPrimary : preset.lightPrimary;
    }

    // تشخیص خودکار رنگ متن روی دکمهها بر اساس روشنایی رنگ اصلی (سیاه روی سبز روشن، سفید روی سبز تیره)
    final bool isPrimaryBright =
        ThemeData.estimateBrightnessForColor(effectivePrimary) ==
            Brightness.light;
    final Color onPrimaryText = isPrimaryBright ? Colors.black : Colors.white;

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor =
        isDark ? const Color(0xFFF5F7F5) : const Color(0xFF0F1712);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor: bgColor,
      primaryColor: effectivePrimary,
      cardColor: cardColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: effectivePrimary,
        onPrimary: onPrimaryText,
        secondary: preset.secondary,
        onSecondary: Colors.black,
        error: AppColors.danger,
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: textColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFF111513),
        foregroundColor: Colors.white, // هدر همیشه مشکی کربنی لوکس با متن سفید و سبز مکسجیم
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark
                ? effectivePrimary.withOpacity(0.18)
                : Colors.black.withOpacity(0.08),
            width: 1.2,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF222925) : const Color(0xFFE6ECE8),
        selectedColor: effectivePrimary.withOpacity(isDark ? 0.28 : 0.18),
        labelStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF151A17) : Colors.white,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black45),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectivePrimary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: onPrimaryText,
          elevation: isDark ? 4 : 2,
          shadowColor: effectivePrimary.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effectivePrimary,
        foregroundColor: onPrimaryText,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: effectivePrimary.withOpacity(0.22),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
