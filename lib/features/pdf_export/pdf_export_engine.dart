import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/cache/smart_cache_manager.dart';
import '../../core/theme/branding_model.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_models.dart';
import '../athletes/domain/scientific_bio_calculator.dart';

enum PdfLanguageMode { bilingual, persianOnly, englishOnly }

class PdfExportEngine {
  /// متد کمکی ساخت نام دقیق فایل طبق دستورالعمل: [Athlete_Full_Name]_[Shamsi_Registration_Date].pdf
  /// مثال: Ali_Rezaei_1405-08-18.pdf
  static String buildDynamicFileName(
      AthleteEntity athlete, DateTime registrationDate) {
    final j = Jalali.fromDateTime(registrationDate);
    final shamsiStr =
        '${j.year}-${j.month.toString().padLeft(2, '0')}-${j.day.toString().padLeft(2, '0')}';

    final cleanName = athlete.fullName
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF_]'), '');

    return '${cleanName}_$shamsiStr.pdf';
  }

  static String _formatShamsiDisplay(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  static String _formatMiladiDisplay(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// بارگذاری فونت فارسی از پوشه assets یا دانلود ایمن فونت وزیرمتن در صورت عدم وجود فایل
  static Future<pw.Font> _loadRegularFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      try {
        return await PdfGoogleFonts.vazirmatnRegular()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        return pw.Font.helvetica();
      }
    }
  }

  static Future<pw.Font> _loadBoldFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      try {
        return await PdfGoogleFonts.vazirmatnBold()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        return pw.Font.helveticaBold();
      }
    }
  }

  /// بازیابی تصاویر شروع و پایان حرکت از کش آفلاین گوشی (بدون مصرف اینترنت مجدد)
  static Future<pw.ImageProvider?> _getCachedImageOrNull(String url) async {
    if (url.isEmpty) return null;
    try {
      final fileInfo =
          await SmartExerciseCacheManager.instance.getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        final bytes = await fileInfo.file.readAsBytes();
        return pw.MemoryImage(bytes);
      }
      // اگر در کش نبود و اینترنت وصل بود، دانلود و کش کن
      final file = await SmartExerciseCacheManager.instance
          .getSingleFile(url)
          .timeout(const Duration(seconds: 3));
      if (await file.exists()) {
        return pw.MemoryImage(await file.readAsBytes());
      }
    } catch (_) {}
    return null;
  }

  /// تولید، پیشنمایش و اشتراکگذاری PDF همراه با کپی کپشن واتساپ و حذف خودکار فایل موقت
  static Future<void> generateAndShareProgramPdf({
    required BuildContext context,
    required BrandingConfig branding,
    required AthleteEntity athlete,
    required FullProgramEntity program,
    required List<MeasurementLogEntity> measurements,
    PdfLanguageMode langMode = PdfLanguageMode.bilingual,
  }) async {
    final isRtl = langMode != PdfLanguageMode.englishOnly;

    // نمایش لودینگ در حین رندرینگ برداری PDF
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    File? tempPdfFile;
    try {
      final fontReg = await _loadRegularFont();
      final fontBold = await _loadBoldFont();

      // بارگذاری لوگوی باشگاه در صورت وجود
      pw.ImageProvider? logoImage;
      if (branding.logoPath != null && File(branding.logoPath!).existsSync()) {
        final logoBytes = await File(branding.logoPath!).readAsBytes();
        logoImage = pw.MemoryImage(logoBytes);
      }

      // پیشبارگذاری تصاویر شروع و پایان حرکات از کش آفلاین
      final Map<String, pw.ImageProvider?> startImages = {};
      final Map<String, pw.ImageProvider?> endImages = {};
      for (final day in program.days) {
        if (day.isRestDay) continue;
        for (final ex in day.exercises) {
          startImages[ex.id] = await _getCachedImageOrNull(ex.imageStartUrl);
          endImages[ex.id] = await _getCachedImageOrNull(ex.imageEndUrl);
        }
      }

      final latestLog = measurements.isNotEmpty ? measurements.last : null;
      final baselineLog = measurements.isNotEmpty ? measurements.first : null;

      final bio = ScientificBioCalculator.analyze(
        gender: athlete.gender,
        age: athlete.age,
        heightCm: athlete.heightCm,
        weightKg: athlete.weightKg,
        fitnessGoal: athlete.fitnessGoal,
        bodyFatPercent: latestLog?.bodyFatPercent,
        waistCm: latestLog?.waistCm,
      );

      final brandPdfColor = PdfColor.fromInt(branding.activePreset.primary.value);
      final darkHeaderColor = PdfColor.fromHex('#181B22');

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontReg,
          bold: fontBold,
        ),
      );

      final shamsiDate = _formatShamsiDisplay(program.startDate);
      final miladiDate = _formatMiladiDisplay(program.startDate);

      // =======================================================================
      // صفحه ۱: کاور برندینگ + تحلیل علمی ماکروها + جدول پیشرفت سایزهای آنتروپومتریک
      // =======================================================================
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          header: (ctx) => _buildBrandHeader(
            branding: branding,
            logoImage: logoImage,
            brandColor: brandPdfColor,
            darkColor: darkHeaderColor,
            shamsiDate: shamsiDate,
            miladiDate: miladiDate,
            isRtl: isRtl,
          ),
          footer: (ctx) => _buildFooter(ctx, branding, isRtl),
          build: (ctx) => [
            pw.SizedBox(height: 14),
            // ۱. کادر مشخصات ورزشکار و تاریخ شمسی/میلادی
            _buildAthleteCoverCard(
                athlete, program, shamsiDate, miladiDate, brandPdfColor, isRtl),
            pw.SizedBox(height: 14),

            // ۲. جدول تحلیل علمی بدن و درشتمغذیها (BMI, WHtR, BMR, TDEE, Macros, Fiber, Water)
            _buildSectionTitle(
              isRtl
                  ? 'تحلیل علمی فیزیولوژی و درشتمغذیهای روزانه (Scientific Bio & Macros)'
                  : 'Scientific Physiology & Daily Macro Targets',
              brandPdfColor,
            ),
            pw.SizedBox(height: 6),
            _buildScientificBioTable(bio, isRtl),
            pw.SizedBox(height: 14),

            // ۳. جدول مقایسه سایزهای آنتروپومتریک (شروع دوره در برابر آخرین رکورد)
            if (baselineLog != null && latestLog != null) ...[
              _buildSectionTitle(
                isRtl
                    ? 'گزارش تغییرات سایز و آنتروپومتریک (Anthropometric Progress)'
                    : 'Anthropometric Measurements Progress',
                brandPdfColor,
              ),
              pw.SizedBox(height: 6),
              _buildAnthropometricsComparisonTable(
                  baselineLog, latestLog, isRtl),
              pw.SizedBox(height: 16),
            ],

            // ۴. برنامه تمرینی تفکیکی روزهای هفته (Macro & Micro Workout Plan)
            _buildSectionTitle(
              isRtl
                  ? 'برنامه تخصصی تمرینات بدنسازی (Workout Routine Split)'
                  : 'Customized Workout Split & Execution Protocol',
              brandPdfColor,
            ),
            pw.SizedBox(height: 8),
            ...program.days.where((d) => !d.isRestDay).map((day) {
              return _buildWorkoutDaySection(
                day: day,
                startImages: startImages,
                endImages: endImages,
                brandColor: brandPdfColor,
                langMode: langMode,
                isRtl: isRtl,
              );
            }),

            pw.SizedBox(height: 16),

            // ۵. برنامه رژیم غذایی و جایگزینها (Nutrition & Alternatives)
            if (program.dietMeals.any((m) => m.items.isNotEmpty)) ...[
              _buildSectionTitle(
                isRtl
                    ? 'برنامه زمانبندی تغذیه و جایگزینها (آب روزانه: ${program.waterLiters.toStringAsFixed(1)} لیتر)'
                    : 'Daily Nutrition Schedule (Hydration: ${program.waterLiters.toStringAsFixed(1)} L)',
                brandPdfColor,
              ),
              pw.SizedBox(height: 6),
              _buildDietTable(program.dietMeals, langMode, isRtl),
              pw.SizedBox(height: 16),
            ],

            // ۶. پروتکل مکملهای ورزشی (Supplement Stack)
            if (program.supplements.isNotEmpty) ...[
              _buildSectionTitle(
                isRtl
                    ? 'پروتکل علمی مصرف مکملها (Supplement Protocol)'
                    : 'Supplement Stack & Timing Protocol',
                brandPdfColor,
              ),
              pw.SizedBox(height: 6),
              _buildSupplementsTable(program.supplements, langMode, isRtl),
            ],
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName = buildDynamicFileName(athlete, program.startDate);

      // ذخیره در پوشه موقت (TemporaryDirectory) تا حافظه دائمی گوشی پر نشود
      final tempDir = await getTemporaryDirectory();
      tempPdfFile = File(p.join(tempDir.path, fileName));
      await tempPdfFile.writeAsBytes(bytes, flush: true);

      // کپی خودکار کپشن انگیزشی واتساپ در کلیپبورد مربی
      final caption = isRtl
          ? 'سلام ${athlete.firstName} عزیز 🌟\n'
              'فایل برنامه تخصصی دوره جدیدت (${program.title}) تاریخ $shamsiDate آماده شد.\n'
              '🔥 کالری هدف روزانه: ${bio.targetCalories} kcal | پروتئین: ${bio.proteinGrams}g | آب: ${program.waterLiters} لیتر\n'
              'نکات اجرایی، تمپوها و سوپرستها داخل PDF کامل درج شده. با قدرت ادامه بده! 💪🏆\n'
              '${branding.coachName} - ${branding.gymName}'
          : 'Hi ${athlete.firstName}! 🌟 Here is your new customized training & nutrition plan ($shamsiDate / $miladiDate). Let\'s crush your goals! 💪🔥 - ${branding.coachName}';

      await Clipboard.setData(ClipboardData(text: caption));

      if (context.mounted) {
        Navigator.of(context).pop(); // بستن دیالوگ لودینگ
      }

      // اشتراکگذاری مستقیم فایل با نام دقیق Ali_Rezaei_1405-08-18.pdf
      await Share.shareXFiles(
        [XFile(tempPdfFile.path, name: fileName, mimeType: 'application/pdf')],
        text: caption,
        subject: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Error: $e')),
        );
      }
    } finally {
      // پاکسازی خودکار فایل موقت پس از ۳۰ ثانیه برای حفظ استراتژی Zero-Bloat
      if (tempPdfFile != null) {
        final fileToDelete = tempPdfFile;
        Future.delayed(const Duration(seconds: 30), () async {
          try {
            if (await fileToDelete.exists()) {
              await fileToDelete.delete();
            }
          } catch (_) {}
        });
      }
    }
  }

  static pw.Widget _buildBrandHeader({
    required BrandingConfig branding,
    required pw.ImageProvider? logoImage,
    required PdfColor brandColor,
    required PdfColor darkColor,
    required String shamsiDate,
    required String miladiDate,
    required bool isRtl,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: darkColor,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border(
          bottom: pw.BorderSide(color: brandColor, width: 3),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 44,
                  height: 44,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    image: pw.DecorationImage(
                        image: logoImage, fit: pw.BoxFit.cover),
                  ),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    branding.gymName,
                    style: pw.TextStyle(
                      color: brandColor,
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${branding.coachName} | ${branding.coachCredentials}',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                isRtl ? 'تاریخ شمسی: $shamsiDate' : 'Shamsi: $shamsiDate',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Miladi: $miladiDate',
                style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8),
              ),
              pw.Text(
                branding.socialHandle,
                style: pw.TextStyle(color: brandColor, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAthleteCoverCard(
    AthleteEntity athlete,
    FullProgramEntity program,
    String shamsiDate,
    String miladiDate,
    PdfColor brandColor,
    bool isRtl,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F4F6F9'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isRtl
                    ? 'نام ورزشکار: ${athlete.fullName}'
                    : 'Athlete: ${athlete.fullName}',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                isRtl
                    ? 'عنوان دوره: ${program.title} (مدت اعتبار: ${program.durationWeeks} هفته)'
                    : 'Program: ${program.title} (${program.durationWeeks} Weeks)',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                isRtl
                    ? 'سن: ${athlete.age} | قد: ${athlete.heightCm.toStringAsFixed(0)}cm | وزن: ${athlete.weightKg.toStringAsFixed(1)}kg'
                    : 'Age: ${athlete.age} | Height: ${athlete.heightCm.toStringAsFixed(0)}cm | Weight: ${athlete.weightKg.toStringAsFixed(1)}kg',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              if (athlete.injuryTags.isNotEmpty)
                pw.Text(
                  isRtl
                      ? 'ملاحظات مفصلی: ${athlete.injuryTags.join(", ")}'
                      : 'Injuries: ${athlete.injuryTags.join(", ")}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.deepOrange),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScientificBioTable(BioAnalysisResult bio, bool isRtl) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#222630')),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      headers: isRtl
          ? [
              'آب روزانه',
              'فیبر (Fiber)',
              'چربی (Fat)',
              'کربوهیدرات',
              'پروتئین',
              'کالری هدف',
              'WHtR (کمر به قد)',
              'شاخص BMI',
            ]
          : [
              'BMI',
              'WHtR',
              'Target kcal',
              'Protein',
              'Carbs',
              'Healthy Fat',
              'Fiber',
              'Water',
            ],
      data: [
        isRtl
            ? [
                '${bio.waterLiters} L',
                '${bio.fiberGrams} g',
                '${bio.fatGrams} g',
                '${bio.carbsGrams} g',
                '${bio.proteinGrams} g',
                '${bio.targetCalories} kcal',
                '${bio.whtr ?? "--"} (${bio.whtrStatusFa})',
                '${bio.bmi} (${bio.bmiCategoryFa})',
              ]
            : [
                '${bio.bmi} (${bio.bmiCategoryEn})',
                '${bio.whtr ?? "--"}',
                '${bio.targetCalories} kcal',
                '${bio.proteinGrams} g',
                '${bio.carbsGrams} g',
                '${bio.fatGrams} g',
                '${bio.fiberGrams} g',
                '${bio.waterLiters} L',
              ],
      ],
    );
  }

  static pw.Widget _buildAnthropometricsComparisonTable(
    MeasurementLogEntity baseline,
    MeasurementLogEntity latest,
    bool isRtl,
  ) {
    String fmt(double? v) => v != null ? v.toStringAsFixed(1) : '-';
    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerStyle: pw.TextStyle(
          color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      headers: isRtl
          ? [
              'ران (cm)',
              'بازو (cm)',
              'دور کمر (cm)',
              'سینه (cm)',
              'سرشانه (cm)',
              'درصد چربی',
              'وزن (kg)',
              'مرحله سایزگیری'
            ]
          : [
              'Check-in Stage',
              'Weight',
              'Body Fat %',
              'Shoulder',
              'Chest',
              'Waist',
              'Biceps',
              'Thigh'
            ],
      data: [
        isRtl
            ? [
                fmt(baseline.thighCm),
                fmt(baseline.bicepsCm),
                fmt(baseline.waistCm),
                fmt(baseline.chestCm),
                fmt(baseline.shoulderCm),
                fmt(baseline.bodyFatPercent),
                fmt(baseline.weightKg),
                'شروع (Baseline)',
              ]
            : [
                'Baseline',
                fmt(baseline.weightKg),
                fmt(baseline.bodyFatPercent),
                fmt(baseline.shoulderCm),
                fmt(baseline.chestCm),
                fmt(baseline.waistCm),
                fmt(baseline.bicepsCm),
                fmt(baseline.thighCm),
              ],
        isRtl
            ? [
                fmt(latest.thighCm),
                fmt(latest.bicepsCm),
                fmt(latest.waistCm),
                fmt(latest.chestCm),
                fmt(latest.shoulderCm),
                fmt(latest.bodyFatPercent),
                fmt(latest.weightKg),
                'فعلی (Latest)',
              ]
            : [
                'Latest Check-in',
                fmt(latest.weightKg),
                fmt(latest.bodyFatPercent),
                fmt(latest.shoulderCm),
                fmt(latest.chestCm),
                fmt(latest.waistCm),
                fmt(latest.bicepsCm),
                fmt(latest.thighCm),
              ],
      ],
    );
  }

  static pw.Widget _buildWorkoutDaySection({
    required WorkoutDayPlan day,
    required Map<String, pw.ImageProvider?> startImages,
    required Map<String, pw.ImageProvider?> endImages,
    required PdfColor brandColor,
    required PdfLanguageMode langMode,
    required bool isRtl,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#181B22'),
              borderRadius:
                  const pw.BorderRadius.vertical(top: pw.Radius.circular(7)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  isRtl
                      ? '${day.dayNameFa} (${day.dayNameEn})'
                      : day.dayNameEn,
                  style: pw.TextStyle(
                    color: brandColor,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  day.targetMuscles.join(' + ').toUpperCase(),
                  style:
                      const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                ),
              ],
            ),
          ),
          ...day.exercises.map((ex) {
            final startImg = startImages[ex.id];
            final endImg = endImages[ex.id];
            final isSuperset = ex.supersetGroupId != null;

            String displayMoveName;
            if (langMode == PdfLanguageMode.persianOnly) {
              displayMoveName = ex.exerciseNameFa;
            } else if (langMode == PdfLanguageMode.englishOnly) {
              displayMoveName = ex.exerciseNameEn;
            } else {
              displayMoveName = '${ex.exerciseNameFa} (${ex.exerciseNameEn})';
            }

            final setsSummary = ex.sets
                .map((s) =>
                    'S${s.setNumber}: ${s.reps}${s.isDropSet ? "[Drop]" : ""}')
                .join(' | ');
            final tempoAndRest = ex.sets.isNotEmpty
                ? 'Tempo: ${ex.sets.first.tempo} | Rest: ${ex.sets.first.restSeconds}s'
                : '';

            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: isSuperset
                    ? PdfColor.fromHex('#FFFBEB')
                    : PdfColors.white,
                border: const pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              child: pw.Row(
                children: [
                  // نمایش ۲ تصویر موقعیت شروع و پایان حرکت از کش آفلاین + QR Code آنلاین
                  pw.Row(
                    children: [
                      if (startImg != null)
                        pw.Container(
                          width: 34,
                          height: 34,
                          margin: const pw.EdgeInsets.only(right: 4),
                          child: pw.Image(startImg, fit: pw.BoxFit.cover),
                        ),
                      if (endImg != null)
                        pw.Container(
                          width: 34,
                          height: 34,
                          margin: const pw.EdgeInsets.only(right: 6),
                          child: pw.Image(endImg, fit: pw.BoxFit.cover),
                        ),
                      pw.UrlLink(
                        destination:
                            'https://www.youtube.com/results?search_query=${Uri.encodeComponent("${ex.exerciseNameEn.isNotEmpty ? ex.exerciseNameEn : ex.exerciseNameFa} form tutorial")}',
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data:
                              'https://www.youtube.com/results?search_query=${Uri.encodeComponent("${ex.exerciseNameEn.isNotEmpty ? ex.exerciseNameEn : ex.exerciseNameFa} form tutorial")}',
                          width: 26,
                          height: 26,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                '${ex.orderIndex}. $displayMoveName',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isSuperset)
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.amber200,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(
                                  'SUPERSET (${ex.supersetGroupId})',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(setsSummary,
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                          tempoAndRest,
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700),
                        ),
                        if (ex.coachNote.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Note: ${ex.coachNote}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.blueGrey800,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildDietTable(
    List<DietMealSlot> meals,
    PdfLanguageMode langMode,
    bool isRtl,
  ) {
    final rows = <List<String>>[];
    for (final m in meals) {
      if (m.items.isEmpty) continue;
      final content = m.items.map((item) {
        final mainFood = isRtl
            ? '${item.foodNameFa} (${item.amountFa})'
            : '${item.foodNameEn} (${item.amountEn})';
        final alts = isRtl ? item.alternativesFa : item.alternativesEn;
        if (alts.isEmpty) return '• $mainFood';
        return isRtl
            ? '• $mainFood [یا جایگزین: ${alts.join(" / ")}]'
            : '• $mainFood [OR: ${alts.join(" / ")}]';
      }).join('\n');

      rows.add(
        isRtl
            ? [content, m.timeRange, m.titleFa]
            : [m.titleEn, m.timeRange, content],
      );
    }

    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#222630')),
      headerStyle: pw.TextStyle(
          color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headers: isRtl
          ? ['اقلام غذایی و جایگزینها (OR)', 'ساعت', 'وعده غذایی']
          : ['Meal Slot', 'Time', 'Foods & Alternatives'],
      data: rows,
    );
  }

  static pw.Widget _buildSupplementsTable(
    List<SupplementPrescriptionItem> list,
    PdfLanguageMode langMode,
    bool isRtl,
  ) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#222630')),
      headerStyle: pw.TextStyle(
          color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headers: isRtl
          ? ['روز مصرف', 'زمان مصرف', 'دوز مصرفی', 'نام مکمل']
          : ['Supplement Name', 'Dosage', 'Timing', 'Condition'],
      data: list.map((s) {
        return isRtl
            ? [
                s.onlyTrainingDays ? 'فقط روزهای تمرین' : 'همه روزها',
                s.timingFa,
                s.dosageFa,
                '${s.nameFa} (${s.nameEn})',
              ]
            : [
                s.nameEn,
                s.dosageEn,
                s.timingEn,
                s.onlyTrainingDays ? 'Training Days Only' : 'Daily',
              ];
      }).toList(),
    );
  }

  static pw.Widget _buildSectionTitle(String title, PdfColor brandColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#222630'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: brandColor,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(
      pw.Context ctx, BrandingConfig branding, bool isRtl) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${branding.gymName} | ${branding.coachName} (${branding.socialHandle})',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}
