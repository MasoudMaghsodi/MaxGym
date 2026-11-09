import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  bool get isFa => locale.languageCode == 'fa';

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(const Locale('fa'));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'fa': {
      'app_title': 'پرو کوچ | مدیریت هوشمند ورزشکاران',
      'dashboard': 'داشبورد مربی',
      'athletes': 'ورزشکاران',
      'templates': 'قالبهای آماده',
      'settings': 'تنظیمات و برندینگ',
      'coach_name': 'نام و نام خانوادگی مربی',
      'coach_credentials': 'مدارک و عناوین مربی (چاپ در PDF)',
      'gym_name': 'نام باشگاه / برند شخصی',
      'instagram_id': 'آیدی اینستاگرام یا تلگرام',
      'theme_mode': 'پوسته اپلیکیشن',
      'dark_mode': 'حالت تاریک (مناسب باشگاه)',
      'light_mode': 'حالت روشن',
      'app_language': 'زبان اپلیکیشن و خروجی',
      'brand_color': 'رنگ سازمانی (اپلیکیشن و PDF)',
      'select_logo': 'انتخاب لوگوی باشگاه / مربی',
      'change_logo': 'تغییر لوگو',
      'remove_logo': 'حذف لوگو',
      'financial_defaults': 'تعرفه پایه خدمات و پکیجها (تومان)',
      'tuition_fee': 'شهریه پایه باشگاه',
      'workout_fee': 'تعرفه برنامه تمرینی',
      'diet_fee': 'تعرفه رژیم غذایی',
      'supplement_fee': 'تعرفه برنامه مکمل',
      'save_settings': 'ذخیره تنظیمات برندینگ',
      'settings_saved': 'تنظیمات با موفقیت ذخیره شد!',
      'clear_media_cache': 'پاکسازی حافظه کش تصاویر (حداکثر ۵۰ مگابایت)',
      'cache_cleared': 'حافظه کش تصاویر پاکسازی شد.',
      'new_athlete': 'شاگرد جدید +',
      'expiring_programs': 'برنامههای رو به اتمام',
      'unpaid_invoices': 'بدهکاران شهریه و برنامه',
    },
    'en': {
      'app_title': 'ProCoach | Athlete Management',
      'dashboard': 'Coach Dashboard',
      'athletes': 'Athletes',
      'templates': 'Smart Templates',
      'settings': 'Settings & Branding',
      'coach_name': 'Coach Full Name',
      'coach_credentials': 'Coach Credentials (Printed on PDF)',
      'gym_name': 'Gym / Personal Brand Name',
      'instagram_id': 'Instagram / Social Handle',
      'theme_mode': 'App Theme Mode',
      'dark_mode': 'Dark Mode (Gym Friendly)',
      'light_mode': 'Light Mode',
      'app_language': 'App Language',
      'brand_color': 'Brand Accent Color (UI & PDF)',
      'select_logo': 'Select Gym / Coach Logo',
      'change_logo': 'Change Logo',
      'remove_logo': 'Remove Logo',
      'financial_defaults': 'Base Service & Package Rates',
      'tuition_fee': 'Base Gym Tuition Fee',
      'workout_fee': 'Workout Plan Fee',
      'diet_fee': 'Nutrition Plan Fee',
      'supplement_fee': 'Supplement Protocol Fee',
      'save_settings': 'Save Branding Settings',
      'settings_saved': 'Settings saved successfully!',
      'clear_media_cache': 'Clear Exercise Media Cache (Max 50MB)',
      'cache_cleared': 'Media cache cleared successfully.',
      'new_athlete': '+ New Athlete',
      'expiring_programs': 'Expiring Programs',
      'unpaid_invoices': 'Unpaid / Pending Invoices',
    },
  };

  String tr(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  /// متد کمکی برای انتخاب متن دوزبانه از دیتابیس بر اساس زبان فعلی اپ
  String bilingual(String faText, String enText) {
    if (isFa) {
      return faText.isNotEmpty ? faText : enText;
    } else {
      return enText.isNotEmpty ? enText : faText;
    }
  }
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['fa', 'en'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
