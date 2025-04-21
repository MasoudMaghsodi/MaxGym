import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>(
    (ref) => SettingsNotifier());

class Settings {
  final Locale locale;
  final bool notificationsEnabled;

  Settings({required this.locale, required this.notificationsEnabled});

  Settings copyWith({Locale? locale, bool? notificationsEnabled}) {
    return Settings(
      locale: locale ?? this.locale,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier()
      : super(
            Settings(locale: const Locale('en'), notificationsEnabled: true)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language') ?? 'en';
    final notificationsEnabled = prefs.getBool('notifications') ?? true;
    state = Settings(
      locale: Locale(languageCode),
      notificationsEnabled: notificationsEnabled,
    );
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    state = state.copyWith(locale: Locale(languageCode));
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }
}
