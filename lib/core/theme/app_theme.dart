import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'branding_model.dart';

class AppTheme {
  static ThemeData buildTheme(BrandingConfig config, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final preset = config.activePreset;

    final Color effectivePrimary;
    if (config.customPrimaryColorHex != null) {
      effectivePrimary = Color(config.customPrimaryColorHex!);
    } else {
      effectivePrimary = isDark ? preset.darkPrimary : preset.lightPrimary;
    }

    final bool isPrimaryBright =
        ThemeData.estimateBrightnessForColor(effectivePrimary) ==
            Brightness.light;
    final Color onPrimaryText = isPrimaryBright ? Colors.black : Colors.white;

    final bgColor = isDark ? const Color(0xFF070A08) : AppColors.lightBg;
    final surfaceColor =
        isDark ? const Color(0xFF0F1411) : AppColors.lightSurface;
    final cardColor = isDark ? const Color(0xFF151C18) : AppColors.lightCard;
    final textColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F1712);

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
        backgroundColor:
            isDark ? const Color(0xFF0B0F0D) : const Color(0xFF111513),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 3,
        shadowColor: Colors.black26,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark
                ? effectivePrimary.withOpacity(0.22)
                : Colors.black.withOpacity(0.08),
            width: 1.2,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? const Color(0xFF1C2520) : const Color(0xFFE6ECE8),
        selectedColor: effectivePrimary.withOpacity(isDark ? 0.28 : 0.18),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black12,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF111714) : Colors.white,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.black45,
          fontSize: 13,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.10) : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: effectivePrimary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: onPrimaryText,
          elevation: isDark ? 6 : 2,
          shadowColor: effectivePrimary.withOpacity(0.45),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: effectivePrimary,
          side: BorderSide(color: effectivePrimary.withOpacity(0.55), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effectivePrimary,
        foregroundColor: onPrimaryText,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: effectivePrimary.withOpacity(0.24),
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
