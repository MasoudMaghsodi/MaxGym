extension PersianNumberSanitizer on String {
  /// تبدیل تمام اعداد فارسی (۰-۹) و عربی (٠-٩) و ممیز فارسی به معادل استاندارد انگلیسی
  String toEnglishDigits() {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = trim();
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(persian[i], i.toString());
      result = result.replaceAll(arabic[i], i.toString());
    }
    result = result.replaceAll('٫', '.').replaceAll(',', '.');
    return result;
  }

  double? toSafeDouble({double min = 0, double max = 1000000000}) {
    final cleaned = toEnglishDigits();
    if (cleaned.isEmpty) return null;
    final val = double.tryParse(cleaned);
    if (val == null || val.isNaN || val.isInfinite) return null;
    return val.clamp(min, max);
  }

  int? toSafeInt({int min = 0, int max = 1000000000}) {
    final cleaned = toEnglishDigits();
    if (cleaned.isEmpty) return null;
    final val = int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round();
    if (val == null) return null;
    return val.clamp(min, max);
  }

  /// سپر امنیتی ضد تزریق (Anti-XSS, Anti-SQLi, Anti-Prompt-Injection & Unicode Bidi Sanitizer)
  String toSanitizedText({int maxLength = 250}) {
    var s = trim();
    if (s.isEmpty) return '';

    // ۱. حذف کاراکترهای کنترلی نامرئی، Null-byte و کاراکترهای مخرب تغییر جهت متن (Bidi Override)
    s = s.replaceAll(
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u202A-\u202E\u2066-\u2069]'),
        '');

    // ۲. خنثی‌سازی تگ‌های HTML/Script و دستورات خطرناک
    s = s
        .replaceAll(RegExp(r'<\s*script[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\s*/\s*script\s*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'javascript\s*:', caseSensitive: false), '');

    // ۳. خنثی‌سازی الگوهای رایج Prompt Injection
    s = s.replaceAll(
      RegExp(
        r'(ignore\s+all\s+previous\s+instructions|system\s+prompt\s*:|you\s+are\s+now\s+in\s+developer\s+mode)',
        caseSensitive: false,
      ),
      '[filtered]',
    );

    if (s.length > maxLength) {
      s = s.substring(0, maxLength);
    }
    return s;
  }
}
