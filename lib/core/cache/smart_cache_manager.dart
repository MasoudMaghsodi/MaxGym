import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// مدیر کش اختصاصی با محدودیت حجم برای جلوگیری از پر شدن حافظه گوشی مربی
class SmartExerciseCacheManager {
  static const key = 'smartExerciseMediaCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      // نگهداری فایلها تا ۳۰ روز در صورت استفاده
      stalePeriod: const Duration(days: 30),
      // حداکثر ۲۵۰ تصویر (معادل تقریبی ۴۰ تا ۵۰ مگابایت در کل)
      // تصاویر قدیمیتر به صورت خودکار (LRU) حذف میشوند
      maxNrOfCacheObjects: 250,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// متد کمکی برای پاکسازی دستی کش از بخش تنظیمات در صورت نیاز مربی
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}
