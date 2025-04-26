import 'package:flutter/material.dart';

final lightTheme = ThemeData(
  primaryColor: const Color(0xFFE53935),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  cardColor: const Color(0xFFF5F5F5),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF212121), fontFamily: 'Montserrat'),
    bodyMedium: TextStyle(color: Color(0xFF424242), fontFamily: 'Montserrat'),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF212121)),
  colorScheme: ColorScheme.fromSwatch().copyWith(
    secondary: const Color(0xFFE53935),
    brightness: Brightness.light,
  ),
);

final darkTheme = ThemeData(
  primaryColor: const Color(0xFFE53935),
  scaffoldBackgroundColor: const Color(0xFF212121),
  cardColor: const Color(0xFF424242),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
    bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
  ),
  iconTheme: const IconThemeData(color: Colors.white),
  colorScheme: ColorScheme.fromSwatch().copyWith(
    secondary: const Color(0xFFE53935),
    brightness: Brightness.dark,
  ),
);
