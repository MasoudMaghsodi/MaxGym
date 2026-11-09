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
    // تبدیل ممیز فارسی و کاما به نقطه اعشار استاندارد
    result = result.replaceAll('٫', '.').replaceAll(',', '.');
    return result;
  }

  double? toSafeDouble() {
    final cleaned = toEnglishDigits();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  int? toSafeInt() {
    final cleaned = toEnglishDigits();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round();
  }
}
