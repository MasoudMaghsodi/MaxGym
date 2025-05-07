import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;
  Map<String, String> _localizedValues = {};

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  Future<void> load() async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/locales/${locale.languageCode}.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedValues =
          jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      debugPrint('Error loading localization for ${locale.languageCode}: $e');
      _localizedValues = {};
    }
  }

  String translate(String key) {
    return _localizedValues[key] ?? key;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fa'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
