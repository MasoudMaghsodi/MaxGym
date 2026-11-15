import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/cache/smart_cache_manager.dart';
import '../../core/config/maxgym_brand_config.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/branding_model.dart';
import '../../core/utils/number_parser.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_models.dart';
import '../athletes/domain/scientific_bio_calculator.dart';

enum PdfLanguageMode { bilingual, persianOnly, englishOnly }

class PdfExportEngine {
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

  static Future<pw.Font> _loadRegularFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  static Future<pw.Font> _loadBoldFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helveticaBold();
    }
  }

  /// استخراج مسیر نسبی تصویر حرکت برای استفاده در پروکسی بدون فیلتر Supabase و آینه‌های جایگزین
  static List<String> _buildResilientCandidateUrls(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return const [];

    final List<String> urls = [];
    const marker = '/exercises/';
    final idx = clean.indexOf(marker);
    if (idx != -1) {
      final relativePath = clean.substring(idx + marker.length);
      // ۱. پروکسی بدون فیلتر Supabase Edge Function (تضمین عبور از فیلترینگ و CORS در وب/موبایل)
      urls.add(
        '${SupabaseConfig.supabaseUrl}/functions/v1/maxgym-media-proxy?mode=image&path=${Uri.encodeComponent(relativePath)}',
      );
      // ۲. آدرس مستقیم GitHub Raw با هدر CORS باز
      urls.add(
        'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$relativePath',
      );
    }
    // ۳. آدرس اصلی CDN
    urls.add(clean);
    return urls;
  }

  /// دانلود تضمینی و چندمسیره تصویر حرکت برای درج در PDF (سازگار با وب PWA و اندروید/iOS)
  static Future<pw.ImageProvider?> _getCachedImageOrNull(String url) async {
    if (url.trim().isEmpty) return null;

    // تلاش اول: خواندن فوری از کش دیسک در موبایل/دسکتاپ
    if (!kIsWeb) {
      try {
        final fileInfo =
            await SmartExerciseCacheManager.instance.getFileFromCache(url);
        if (fileInfo != null && await fileInfo.file.exists()) {
          final bytes = await fileInfo.file.readAsBytes();
          if (bytes.isNotEmpty) return pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    // تلاش دوم: امتحان کردن لیست آدرس‌های مقاوم (پروکسی Supabase -> GitHub Raw -> jsDelivr)
    final candidates = _buildResilientCandidateUrls(url);
    for (final candidate in candidates) {
      try {
        if (kIsWeb) {
          final ByteData data = await NetworkAssetBundle(Uri.parse(candidate))
              .load(candidate)
              .timeout(const Duration(seconds: 6));
          final bytes = data.buffer.asUint8List();
          if (bytes.length > 100) {
            return pw.MemoryImage(bytes);
          }
        } else {
          final file = await SmartExerciseCacheManager.instance
              .getSingleFile(candidate)
              .timeout(const Duration(seconds: 6));
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.length > 100) {
              return pw.MemoryImage(bytes);
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static String _buildCleanBilingualName(
      String fa, String en, PdfLanguageMode mode) {
    final cleanFa = fa.trim().toCleanPersian();
    final cleanEn = en.trim();
    if (mode == PdfLanguageMode.persianOnly) return cleanFa;
    if (mode == PdfLanguageMode.englishOnly) return cleanEn;
    if (cleanEn.isEmpty) return cleanFa;
    if (cleanFa.toLowerCase().contains(cleanEn.toLowerCase())) {
      return cleanFa;
    }
    return '$cleanFa ($cleanEn)';
  }

  static Future<void> generateAndShareProgramPdf({
    required BuildContext context,
    required BrandingConfig branding,
    required AthleteEntity athlete,
    required FullProgramEntity program,
    required List<MeasurementLogEntity> measurements,
    PdfLanguageMode langMode = PdfLanguageMode.bilingual,
  }) async {
    final isRtl = langMode != PdfLanguageMode.englishOnly;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF121614),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF72C832)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF72C832)),
              SizedBox(height: 14),
              Text(
                'در حال آماده‌سازی مجله اختصاصی برنامه و تصاویر حرکات...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );

    File? tempPdfFile;
    try {
      final fontReg = await _loadRegularFont();
      final fontBold = await _loadBoldFont();

      pw.ImageProvider? logoImage;
      if (!kIsWeb &&
          branding.logoPath != null &&
          File(branding.logoPath!).existsSync()) {
        final logoBytes = await File(branding.logoPath!).readAsBytes();
        logoImage = pw.MemoryImage(logoBytes);
      } else {
        try {
          final bundledLogo =
              await rootBundle.load('assets/images/maxgym_logo.jpeg');
          logoImage = pw.MemoryImage(bundledLogo.buffer.asUint8List());
        } catch (_) {}
      }

      // دانلود موازی (Parallel Batch Fetching) تمام تصاویر شروع و پایان حرکات برای سرعت ۵ برابری
      final Map<String, pw.ImageProvider?> startImages = {};
      final Map<String, pw.ImageProvider?> endImages = {};
      final List<Future<void>> imageTasks = [];

      for (final day in program.days) {
        if (day.isRestDay) continue;
        for (final ex in day.exercises) {
          final startUrl = ex.imageStartUrl.isNotEmpty
              ? ex.imageStartUrl
              : 'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/${ex.exerciseId}/0.jpg';
          final endUrl = ex.imageEndUrl.isNotEmpty
              ? ex.imageEndUrl
              : 'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/${ex.exerciseId}/1.jpg';

          imageTasks.add(() async {
            startImages[ex.id] = await _getCachedImageOrNull(startUrl);
            endImages[ex.id] = await _getCachedImageOrNull(endUrl);
          }());
        }
      }
      await Future.wait(imageTasks);

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

      final brandPdfColor =
          PdfColor.fromInt(branding.activePreset.primary.value);
      final darkHeaderColor = PdfColor.fromHex('#0F1412');

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontReg,
          bold: fontBold,
        ),
      );

      final shamsiDate = _formatShamsiDisplay(program.startDate);
      final miladiDate = _formatMiladiDisplay(program.startDate);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
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
            pw.SizedBox(height: 12),
            _buildAthleteCoverCard(
                athlete, program, shamsiDate, miladiDate, brandPdfColor, isRtl),
            pw.SizedBox(height: 12),
            _buildSectionTitle(
              isRtl
                  ? '۱. مهندسی متابولیک، کالری و توزیع درشت‌مغذی‌ها (Scientific Bio & Macros)'
                  : '1. Metabolic Engineering & Daily Macro Distribution',
              brandPdfColor,
            ),
            pw.SizedBox(height: 6),
            _buildScientificBioAndMacroBar(bio, brandPdfColor, isRtl),
            pw.SizedBox(height: 12),
            if (baselineLog != null && latestLog != null) ...[
              _buildSectionTitle(
                isRtl
                    ? '۲. کارنامه آنتروپومتریک و تغییرات سایز بدنی (Anthropometric Progress)'
                    : '2. Anthropometric Measurements & Delta Progress',
                brandPdfColor,
              ),
              pw.SizedBox(height: 6),
              _buildAnthropometricsComparisonTable(
                  baselineLog, latestLog, isRtl),
              pw.SizedBox(height: 14),
            ],
            _buildSectionTitle(
              isRtl
                  ? '۳. پروتکل تخصصی تمرینات بدنسازی به همراه راهنمای تصویری (Workout Split)'
                  : '3. Customized Workout Split & Visual Execution Guide',
              brandPdfColor,
            ),
            pw.SizedBox(height: 6),
            _buildTempoAndRirLegendBox(isRtl),
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
            pw.SizedBox(height: 14),
            if (program.dietMeals.any((m) => m.items.isNotEmpty)) ...[
              _buildSectionTitle(
                isRtl
                    ? '۴. مهندسی وعده‌های غذایی و جایگزین‌ها (آب روزانه: ${program.waterLiters.toStringAsFixed(1)} لیتر)'
                    : '4. Daily Nutrition Schedule (Hydration: ${program.waterLiters.toStringAsFixed(1)} L)',
                brandPdfColor,
              ),
              pw.SizedBox(height: 6),
              _buildDietTable(program.dietMeals, langMode, isRtl),
              if (program.dietGuidelines.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                _buildDietGuidelinesBox(program.dietGuidelines, isRtl),
              ],
              pw.SizedBox(height: 14),
            ],
            if (program.supplements.isNotEmpty) ...[
              _buildSectionTitle(
                isRtl
                    ? '۵. پروتکل زمان‌بندی و دوز علمی مکمل‌ها (Supplement Stack)'
                    : '5. Supplement Stack & Timing Protocol',
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

      final caption = isRtl
          ? 'سلام ${athlete.firstName} عزیز 🌟\n'
              'فایل برنامه تخصصی دوره جدیدت (${program.title.toCleanPersian()}) تاریخ $shamsiDate آماده شد.\n'
              '🔑 کد ورود آنلاین شما به اپلیکیشن: ${athlete.accessCode}\n'
              '🌐 لینک پرتال وب و آیفون: ${MaxGymBrandConfig.pwaWebUrl}\n'
              '🔥 کالری هدف روزانه: ${bio.targetCalories} kcal | پروتئین: ${bio.proteinGrams}g | آب: ${program.waterLiters} لیتر\n'
              '${branding.coachName.toCleanPersian()} - ${branding.gymName.toCleanPersian()}'
          : 'Hi ${athlete.firstName}! 🌟 Here is your new plan ($shamsiDate). Portal Code: ${athlete.accessCode}';

      await Clipboard.setData(ClipboardData(text: caption));

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (kIsWeb) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
          text: caption,
          subject: fileName,
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        tempPdfFile = File(p.join(tempDir.path, fileName));
        await tempPdfFile.writeAsBytes(bytes, flush: true);

        await Share.shareXFiles(
          [XFile(tempPdfFile.path, name: fileName, mimeType: 'application/pdf')],
          text: caption,
          subject: fileName,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Error: $e')),
        );
      }
    } finally {
      final fileToDelete = tempPdfFile;
      if (fileToDelete != null) {
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
    final cleanCoachName = branding.coachName.toCleanPersian();
    final cleanCreds = branding.coachCredentials.toCleanPersian();

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: darkColor,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: brandColor, width: 1.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 46,
                  height: 46,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: brandColor, width: 1.2),
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
                    branding.gymName.toCleanPersian(),
                    style: pw.TextStyle(
                      color: brandColor,
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '$cleanCoachName | $cleanCreds',
                    style:
                        const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(
                      'Online Athlete Portal: ${MaxGymBrandConfig.pwaWebUrl}',
                      style: const pw.TextStyle(
                          color: PdfColors.grey400, fontSize: 7.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                isRtl ? 'تاریخ صدور: $shamsiDate' : 'Date: $shamsiDate',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  'Miladi: $miladiDate',
                  style: const pw.TextStyle(
                      color: PdfColors.grey300, fontSize: 8),
                ),
              ),
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  branding.socialHandle,
                  style: pw.TextStyle(
                      color: brandColor,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold),
                ),
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
    final activeDaysCount = program.days.where((d) => !d.isRestDay).length;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F4F7F5'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    isRtl
                        ? 'ورزشکار: ${athlete.fullName}   |   کد ورود به اپلیکیشن: '
                        : 'Athlete: ${athlete.fullName}   |   Portal Access Code: ',
                    style: const pw.TextStyle(
                        fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#121614'),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Directionality(
                      textDirection: pw.TextDirection.ltr,
                      child: pw.Text(
                        athlete.isCodeBurned
                            ? 'PC-•••••• (Active)'
                            : athlete.accessCode,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: brandColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                isRtl
                    ? 'عنوان دوره: ${program.title.toCleanPersian()}  •  اعتبار: ${program.durationWeeks} هفته ($activeDaysCount جلسه در هفته)'
                    : 'Program: ${program.title}  •  Duration: ${program.durationWeeks} Weeks ($activeDaysCount Days/Week)',
                style: const pw.TextStyle(fontSize: 9.5),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                isRtl
                    ? 'سن: ${athlete.age} سال  |  قد: ${athlete.heightCm.toStringAsFixed(0)} cm  |  وزن: ${athlete.weightKg.toStringAsFixed(1)} kg'
                    : 'Age: ${athlete.age}  |  Height: ${athlete.heightCm.toStringAsFixed(0)}cm  |  Weight: ${athlete.weightKg.toStringAsFixed(1)}kg',
                style: const pw.TextStyle(
                    fontSize: 9.5, fontWeight: pw.FontWeight.bold),
              ),
              if (athlete.injuryTags.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    isRtl
                        ? '⚠️ ملاحظات مفصلی: ${athlete.injuryTags.join(" ، ")}'
                        : '⚠️ Joint Notes: ${athlete.injuryTags.join(", ")}',
                    style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.deepOrange800,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScientificBioAndMacroBar(
      BioAnalysisResult bio, PdfColor brandColor, bool isRtl) {
    final pKcal = bio.proteinGrams * 4;
    final cKcal = bio.carbsGrams * 4;
    final fKcal = bio.fatGrams * 9;
    final total = (pKcal + cKcal + fKcal).clamp(1, 10000);
    final pPct = ((pKcal / total) * 100).round();
    final cPct = ((cKcal / total) * 100).round();
    final fPct = (100 - pPct - cPct).clamp(5, 90);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          headerDecoration:
              pw.BoxDecoration(color: PdfColor.fromHex('#141A17')),
          headerStyle: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellAlignment: pw.Alignment.center,
          headers: isRtl
              ? [
                  'آب روزانه',
                  'فیبر (Fiber)',
                  'چربی مفید ($fPct%)',
                  'کربوهیدرات ($cPct%)',
                  'پروتئین ($pPct%)',
                  'کالری هدف',
                  'تثبیت / پایه',
                  'BMI / WHtR',
                ]
              : [
                  'BMI / WHtR',
                  'BMR / TDEE',
                  'Target kcal',
                  'Protein ($pPct%)',
                  'Carbs ($cPct%)',
                  'Healthy Fat ($fPct%)',
                  'Fiber',
                  'Water',
                ],
          data: [
            isRtl
                ? [
                    '${bio.waterLiters} لیتر',
                    '${bio.fiberGrams} گرم',
                    '${bio.fatGrams}g ($fKcal kcal)',
                    '${bio.carbsGrams}g ($cKcal kcal)',
                    '${bio.proteinGrams}g ($pKcal kcal)',
                    '${bio.targetCalories} kcal',
                    '${bio.tdeeKcal} / ${bio.bmrKcal}',
                    '${bio.bmi} (${bio.bmiCategoryFa.toCleanPersian()})',
                  ]
                : [
                    '${bio.bmi} (${bio.bmiCategoryEn})',
                    '${bio.bmrKcal} / ${bio.tdeeKcal}',
                    '${bio.targetCalories} kcal',
                    '${bio.proteinGrams}g',
                    '${bio.carbsGrams}g',
                    '${bio.fatGrams}g',
                    '${bio.fiberGrams}g',
                    '${bio.waterLiters}L',
                  ],
          ],
        ),
        pw.SizedBox(height: 5),
        // نوار بصری نسبت درشت‌مغذی‌ها (Visual Macro Split Bar)
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: pPct,
                child: pw.Container(
                  height: 10,
                  color: PdfColor.fromHex('#0284C7'),
                  alignment: pw.Alignment.center,
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(
                      'Protein $pPct%',
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
              ),
              pw.Expanded(
                flex: cPct,
                child: pw.Container(
                  height: 10,
                  color: brandColor,
                  alignment: pw.Alignment.center,
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(
                      'Carbs $cPct%',
                      style: const pw.TextStyle(
                          color: PdfColors.black,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
              ),
              pw.Expanded(
                flex: fPct,
                child: pw.Container(
                  height: 10,
                  color: PdfColor.fromHex('#D97706'),
                  alignment: pw.Alignment.center,
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(
                      'Fat $fPct%',
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildAnthropometricsComparisonTable(
    MeasurementLogEntity baseline,
    MeasurementLogEntity latest,
    bool isRtl,
  ) {
    String fmt(double? v) => v != null ? v.toStringAsFixed(1) : '-';
    String delta(double? start, double? end) {
      if (start == null || end == null) return '-';
      final d = end - start;
      if (d == 0) return '0.0';
      return '${d > 0 ? "+" : ""}${d.toStringAsFixed(1)}';
    }

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerStyle: const pw.TextStyle(
          color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
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
              'Stage',
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
                'شروع دوره (Baseline)',
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
                'ثبت فعلی (Latest)',
              ]
            : [
                'Latest',
                fmt(latest.weightKg),
                fmt(latest.bodyFatPercent),
                fmt(latest.shoulderCm),
                fmt(latest.chestCm),
                fmt(latest.waistCm),
                fmt(latest.bicepsCm),
                fmt(latest.thighCm),
              ],
        isRtl
            ? [
                delta(baseline.thighCm, latest.thighCm),
                delta(baseline.bicepsCm, latest.bicepsCm),
                delta(baseline.waistCm, latest.waistCm),
                delta(baseline.chestCm, latest.chestCm),
                delta(baseline.shoulderCm, latest.shoulderCm),
                delta(baseline.bodyFatPercent, latest.bodyFatPercent),
                delta(baseline.weightKg, latest.weightKg),
                'تغییرات (Δ Progress)',
              ]
            : [
                'Delta (Δ)',
                delta(baseline.weightKg, latest.weightKg),
                delta(baseline.bodyFatPercent, latest.bodyFatPercent),
                delta(baseline.shoulderCm, latest.shoulderCm),
                delta(baseline.chestCm, latest.chestCm),
                delta(baseline.waistCm, latest.waistCm),
                delta(baseline.bicepsCm, latest.bicepsCm),
                delta(baseline.thighCm, latest.thighCm),
              ],
      ],
    );
  }

  static pw.Widget _buildTempoAndRirLegendBox(bool isRtl) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EDF2F0'),
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Text(
        isRtl
            ? '📌 راهنمای اجرای علمی: Tempo (چهار عدد از چپ به راست: ثانیه فرود وزنه - مکث پایین - ثانیه بالا بردن - مکث بالا)  |  SUPERSET: اجرای دو حرکت بلافاصله پشت سر هم بدون استراحت  |  Drop Set: کاهش ۲۰٪ وزنه در ست آخر و ادامه تا ناتوانی.'
            : '📌 Execution Legend: Tempo (Eccentric - Bottom Pause - Concentric - Top Pause in seconds) | Superset: Perform back-to-back with no rest.',
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
      ),
    );
  }

  /// کادر جایگزین برداری در صورتی که حرکت سفارشی مربی عکس اینترنتی نداشته باشد
  static pw.Widget _buildVectorPoseFallbackBox(
      String label, String muscle, PdfColor brandColor) {
    return pw.Container(
      width: 52,
      height: 52,
      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#141A17'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: brandColor, width: 0.8),
      ),
      alignment: pw.Alignment.center,
      child: pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              muscle.toUpperCase(),
              style: pw.TextStyle(
                color: brandColor,
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 1,
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              label,
              style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 6,
              ),
            ),
          ],
        ),
      ),
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
    final cleanDayFa = day.dayNameFa.toCleanPersian();
    final totalDaySets =
        day.exercises.fold<int>(0, (sum, item) => sum + item.sets.length);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#141A17'),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  isRtl
                      ? '$cleanDayFa (${day.dayNameEn}) — ${day.exercises.length} حرکت / $totalDaySets ست'
                      : '${day.dayNameEn} — ${day.exercises.length} Exercises / $totalDaySets Sets',
                  style: pw.TextStyle(
                    color: brandColor,
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(
                    day.targetMuscles.join(' + ').toUpperCase(),
                    style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(day.exercises.length, (idx) {
            final ex = day.exercises[idx];
            final startImg = startImages[ex.id];
            final endImg = endImages[ex.id];
            final isSuperset = ex.supersetGroupId != null;

            final displayMoveName = _buildCleanBilingualName(
              ex.exerciseNameFa,
              ex.exerciseNameEn,
              langMode,
            );

            final setsSummary = ex.sets
                .map((s) =>
                    'S${s.setNumber}: ${s.reps}${s.isDropSet ? " [Drop]" : ""}')
                .join('   |   ');
            final tempoAndRest = ex.sets.isNotEmpty
                ? 'Tempo: ${ex.sets.first.tempo}   |   Rest: ${ex.sets.first.restSeconds}s   |   Target: ${ex.targetMuscle.toUpperCase()}'
                : '';

            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: isSuperset
                    ? PdfColor.fromHex('#FFFBEB')
                    : (idx.isEven
                        ? PdfColors.white
                        : PdfColor.fromHex('#F9FBFA')),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 22,
                    height: 22,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#141A17'),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Text(
                      '${idx + 1}',
                      style: pw.TextStyle(
                        color: brandColor,
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                displayMoveName,
                                style: const pw.TextStyle(
                                  fontSize: 9.5,
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
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.ltr,
                                  child: pw.Text(
                                    'SUPERSET (${ex.supersetGroupId})',
                                    style: const pw.TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Directionality(
                          textDirection: pw.TextDirection.ltr,
                          child: pw.Text(
                            setsSummary,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#1B2420'),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Directionality(
                          textDirection: pw.TextDirection.ltr,
                          child: pw.Text(
                            tempoAndRest,
                            style: const pw.TextStyle(
                                fontSize: 7.5, color: PdfColors.grey700),
                          ),
                        ),
                        if (ex.coachNote.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 3),
                            child: pw.Text(
                              isRtl
                                  ? '📌 نکته فنی مربی: ${ex.coachNote.toCleanPersian()}'
                                  : '📌 Coach Note: ${ex.coachNote}',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.deepOrange800,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // قاب دوتایی تصاویر شروع و پایان حرکت (با Fallback برداری تضمینی)
                  pw.Row(
                    children: [
                      if (startImg != null)
                        pw.Container(
                          width: 52,
                          height: 52,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(
                                color: PdfColors.grey400, width: 0.6),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 5,
                            verticalRadius: 5,
                            child: pw.Image(startImg, fit: pw.BoxFit.cover),
                          ),
                        )
                      else
                        _buildVectorPoseFallbackBox(
                            'START', ex.targetMuscle, brandColor),
                      if (endImg != null)
                        pw.Container(
                          width: 52,
                          height: 52,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(
                                color: brandColor, width: 0.9),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 5,
                            verticalRadius: 5,
                            child: pw.Image(endImg, fit: pw.BoxFit.cover),
                          ),
                        )
                      else if (startImg != null)
                        pw.Container(
                          width: 52,
                          height: 52,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(
                                color: brandColor, width: 0.9),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 5,
                            verticalRadius: 5,
                            child: pw.Image(startImg, fit: pw.BoxFit.cover),
                          ),
                        )
                      else
                        _buildVectorPoseFallbackBox(
                            'FINISH', ex.targetMuscle, brandColor),
                    ],
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
            ? '${item.foodNameFa.toCleanPersian()} (${item.amountFa.toCleanPersian()})'
            : '${item.foodNameEn} (${item.amountEn})';
        final alts = isRtl ? item.alternativesFa : item.alternativesEn;
        if (alts.isEmpty) return '• $mainFood';
        return isRtl
            ? '• $mainFood\n   [یا جایگزین: ${alts.join(" / ").toCleanPersian()}]'
            : '• $mainFood\n   [OR: ${alts.join(" / ")}]';
      }).join('\n');

      final cleanMealTitle = m.titleFa.toCleanPersian();
      rows.add(
        isRtl
            ? [content, m.timeRange, cleanMealTitle]
            : [m.titleEn, m.timeRange, content],
      );
    }

    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#141A17')),
      headerStyle: const pw.TextStyle(
          color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      headers: isRtl
          ? ['اقلام غذایی و جایگزین‌ها (OR Logic)', 'ساعت', 'وعده غذایی']
          : ['Meal Slot', 'Time', 'Foods & Alternatives'],
      data: rows,
    );
  }

  static pw.Widget _buildDietGuidelinesBox(
      List<String> guidelines, bool isRtl) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F4F7F5'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: guidelines
            .map((g) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    '✓ ${g.toCleanPersian()}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ))
            .toList(),
      ),
    );
  }

  static pw.Widget _buildSupplementsTable(
    List<SupplementPrescriptionItem> list,
    PdfLanguageMode langMode,
    bool isRtl,
  ) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#141A17')),
      headerStyle: const pw.TextStyle(
          color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      headers: isRtl
          ? ['روز مصرف', 'زمان مصرف', 'دوز مصرفی', 'نام مکمل']
          : ['Supplement Name', 'Dosage', 'Timing', 'Condition'],
      data: list.map((s) {
        final cleanSuppName =
            _buildCleanBilingualName(s.nameFa, s.nameEn, langMode);
        return isRtl
            ? [
                s.onlyTrainingDays ? 'فقط روزهای تمرین' : 'همه روزها',
                s.timingFa.toCleanPersian(),
                s.dosageFa.toCleanPersian(),
                cleanSuppName,
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#141A17'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: brandColor,
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(
      pw.Context ctx, BrandingConfig branding, bool isRtl) {
    final cleanCoachName = branding.coachName.toCleanPersian();
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Text(
                '${branding.gymName.toCleanPersian()} | $cleanCoachName | ',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  branding.socialHandle,
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700),
                ),
              ),
            ],
          ),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );
  }
}
