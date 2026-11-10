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

    // پسزمینه مشکی عمیق (Obsidian) و کارتهای ذغالی مات بدون کادر سبز اضافی (الهام از تصویر ۲ و ۳)
    final bgColor = isDark ? const Color(0xFF080A09) : AppColors.lightBg;
    final surfaceColor =
        isDark ? const Color(0xFF101311) : AppColors.lightSurface;
    final cardColor = isDark ? const Color(0xFF151816) : AppColors.lightCard;
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
            isDark ? const Color(0xFF080A09) : const Color(0xFF111513),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black26,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
            width: 1.0,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? const Color(0xFF1A1E1C) : const Color(0xFFE6ECE8),
        selectedColor: effectivePrimary,
        secondarySelectedColor: effectivePrimary,
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.07) : Colors.black12,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: onPrimaryText,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF121513) : Colors.white,
        labelStyle: TextStyle(
          color: isDark ? Colors.white60 : Colors.black87,
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.black45,
          fontSize: 13,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: effectivePrimary, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: onPrimaryText,
          elevation: isDark ? 8 : 2,
          shadowColor: effectivePrimary.withOpacity(0.38),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black87,
          backgroundColor:
              isDark ? const Color(0xFF161A18) : Colors.transparent,
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : effectivePrimary.withOpacity(0.5),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effectivePrimary,
        foregroundColor: onPrimaryText,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0E1110),
        indicatorColor: effectivePrimary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: onPrimaryText, size: 22);
          }
          return const IconThemeData(color: Colors.white54, size: 21);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: effectivePrimary,
            );
          }
          return const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          );
        }),
      ),
    );
  }
}
