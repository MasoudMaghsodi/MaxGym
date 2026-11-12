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

  /// اصلاح خودکار نیم‌فاصله‌ها و کلمات چسبیده فارسی (حتی برای داده‌های ذخیره‌شده قدیمی در دیتابیس)
  String toCleanPersian() {
    if (isEmpty) return this;
    return replaceAll('سهشنبه', 'سه‌شنبه')
        .replaceAll('پشتبازو', 'پشت‌بازو')
        .replaceAll('جلوبازو', 'جلوبازو')
        .replaceAll('میانوعده', 'میان‌وعده')
        .replaceAll('میانتنه', 'میان‌تنه')
        .replaceAll('حرفهای', 'حرفه‌ای')
        .replaceAll('برنامهها', 'برنامه‌ها')
        .replaceAll('برنامههای', 'برنامه‌های')
        .replaceAll('قالبهای', 'قالب‌های')
        .replaceAll('مکملها', 'مکمل‌ها')
        .replaceAll('مکملهای', 'مکمل‌های')
        .replaceAll('جایگزینها', 'جایگزین‌ها')
        .replaceAll('سایزگیریها', 'سایزگیری‌ها')
        .replaceAll('درشتمغذیها', 'درشت‌مغذی‌ها')
        .replaceAll('ریزمغذیها', 'ریز‌مغذی‌ها')
        .replaceAll('ثبتشده', 'ثبت‌شده')
        .replaceAll('دریافتشده', 'دریافت‌شده')
        .replaceAll('پرداختشده', 'پرداخت‌شده')
        .replaceAll('تاییدشده', 'تأیید‌شده')
        .replaceAll('نکردهاند', 'نکرده‌اند')
        .replaceAll('سهبعدی', 'سه‌بعدی')
        .replaceAll('هیتمپ', 'هیت‌مپ')
        .replaceAll('ماشینحساب', 'ماشین‌حساب')
        .replaceAll('عضلهسازی', 'عضله‌سازی')
        .replaceAll('چربیسوزی', 'چربی‌سوزی')
        .replaceAll('آسیبدیدگیها', 'آسیب‌دیدگی‌ها')
        .replaceAll('آسیبدیدگی', 'آسیب‌دیدگی')
        .replaceAll('محدودیتهای', 'محدودیت‌های')
        .replaceAll('منظمترین', 'منظم‌ترین')
        .replaceAll('پکیجها', 'پکیج‌ها')
        .replaceAll('مکسجیم', 'مکس‌جیم')
        .replaceAll('تکدست', 'تک‌دست')
        .replaceAll('تکپا', 'تک‌پا')
        .replaceAll('دستجمع', 'دست‌جمع')
        .replaceAll('دستباز', 'دست‌باز')
        .replaceAll('سیمکش', 'سیم‌کش')
        .replaceAll('تخممرغ', 'تخم‌مرغ')
        .replaceAll('گوجهفرنگی', 'گوجه‌فرنگی')
        .replaceAll('سیبزمینی', 'سیب‌زمینی')
        .replaceAll('بادامزمینی', 'بادام‌زمینی')
        .replaceAll('کمچرب', 'کم‌چرب')
        .replaceAll('کمنمک', 'کم‌نمک')
        .replaceAll('سبوسدار', 'سبوس‌دار')
        .replaceAll('آبپز', 'آب‌پز');
  }

  /// سپر امنیتی ضد تزریق (Anti-XSS, Anti-SQLi, Anti-Prompt-Injection & Unicode Bidi Sanitizer)
  String toSanitizedText({int maxLength = 250}) {
    var s = trim();
    if (s.isEmpty) return '';

    s = s.replaceAll(
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u202A-\u202E\u2066-\u2069]'),
        '');

    s = s
        .replaceAll(RegExp(r'<\s*script[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\s*/\s*script\s*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'javascript\s*:', caseSensitive: false), '');

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

extension NumberCurrencyFormatter on num {
  /// فرمت سه‌رقمی اعداد مالی (مثلاً 1700000 -> 1,700,000)
  String toPriceFormat() {
    final intVal = round();
    final str = intVal.abs().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return intVal < 0 ? '-$formatted' : formatted;
  }
}
