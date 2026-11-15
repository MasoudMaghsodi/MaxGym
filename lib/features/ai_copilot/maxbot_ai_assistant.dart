import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/number_parser.dart';
import '../../core/widgets/telegram_chat_and_notifications.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../athletes/presentation/athletes_provider.dart';

/// مدل دستور عملیاتی استخراج‌شده برای ایجنت مربی (Coach Copilot Action)
enum CoachAiActionType {
  renewAthleteProgram,
  changeAthleteGoal,
  applyTemplateToAthlete,
  broadcastToExpiringAthletes,
  settleAthleteDebt,
}

class CoachAiActionProposal {
  final CoachAiActionType type;
  final String summaryTitleFa;
  final String detailsFa;
  final AthleteEntity? targetAthlete;
  final String? newGoalId;
  final FullProgramEntity? templateToApply;
  final List<AthleteEntity> broadcastTargets;

  const CoachAiActionProposal({
    required this.type,
    required this.summaryTitleFa,
    required this.detailsFa,
    this.targetAthlete,
    this.newGoalId,
    this.templateToApply,
    this.broadcastTargets = const [],
  });
}

class MaxBotChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final CoachAiActionProposal? actionProposal;
  final bool isActionExecuted;
  final DateTime createdAt;

  const MaxBotChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.actionProposal,
    this.isActionExecuted = false,
    required this.createdAt,
  });

  MaxBotChatMessage copyWith({bool? isActionExecuted}) {
    return MaxBotChatMessage(
      id: id,
      isUser: isUser,
      text: text,
      actionProposal: actionProposal,
      isActionExecuted: isActionExecuted ?? this.isActionExecuted,
      createdAt: createdAt,
    );
  }
}

/// گوی شناور و تپنده دستیار هوش مصنوعی (The "MaxBot AI" Floating Neural Orb)
class MaxBotFloatingOrb extends StatefulWidget {
  final bool isCoachMode;
  final AthleteEntity? currentAthlete;

  const MaxBotFloatingOrb({
    super.key,
    required this.isCoachMode,
    this.currentAthlete,
  });

  @override
  State<MaxBotFloatingOrb> createState() => _MaxBotFloatingOrbState();
}

class _MaxBotFloatingOrbState extends State<MaxBotFloatingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // در محیط تست برای جلوگیری از تایم‌اوت pumpAndSettle تکرار بی‌نهایت خاموش است
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const neuralViolet = Color(0xFF8B5CF6);
    const cyberPink = Color(0xFFEC4899);

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final scale = 1.0 + (_pulseCtrl.value * 0.06);
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => MaxBotAiCommandCenterSheet(
                  isCoachMode: widget.isCoachMode,
                  currentAthlete: widget.currentAthlete,
                ),
              );
            },
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [neuralViolet, cyberPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                    color: Colors.white.withOpacity(0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: neuralViolet.withOpacity(0.45 + (_pulseCtrl.value * 0.25)),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'MaxBot AI',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// مرکز فرماندهی شیشه‌ای دستیار هوش مصنوعی (علمی + ایجنت دستوری مربی)
class MaxBotAiCommandCenterSheet extends ConsumerStatefulWidget {
  final bool isCoachMode;
  final AthleteEntity? currentAthlete;

  const MaxBotAiCommandCenterSheet({
    super.key,
    required this.isCoachMode,
    this.currentAthlete,
  });

  @override
  ConsumerState<MaxBotAiCommandCenterSheet> createState() =>
      _MaxBotAiCommandCenterSheetState();
}

class _MaxBotAiCommandCenterSheetState
    extends ConsumerState<MaxBotAiCommandCenterSheet> {
  /// در صورت نیاز به تست مستقیم بدون Edge Function، کلید از --dart-define=GEMINI_API_KEY خوانده می‌شود
  static const String envGeminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<MaxBotChatMessage> _messages = [];
  bool _isThinking = false;

  static const Color _neuralViolet = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    final welcomeText = widget.isCoachMode
        ? 'سلام مربی عزیز! 👋 من **MaxBot AI (دستیار هوشمند فرماندهی باشگاه)** هستم.\n\n'
            'می‌توانید به زبان طبیعی به من دستور بدهید تا کارهای مدیریتی را برایتان انجام دهم؛ مثلاً:\n'
            '• *«برنامه مسعود مقصودی رو تمدید کن»*\n'
            '• *«هدف مسعود رو به کات تغییر بده»*\n'
            '• *«به تمام شاگردان منقضی پیام تمدید بفرست»*\n'
            'یا هر سوال تخصصی درباره طراحی تمرین، تداخل مکمل‌ها و تغذیه بپرسید!'
        : 'سلام ${widget.currentAthlete?.firstName ?? "قهرمان"} عزیز! ⚡ من **MaxBot AI (مشاور علمی بدنسازی و تغذیه MAX GYM)** هستم.\n\n'
            'بر اساس پرونده بیومتریک تو آماده پاسخگویی به سوالات تخصصی درباره فرم اجرای حرکات، جایگزین‌های غذایی، زمان مصرف مکمل‌ها و ریکاوری هستم.';

    _messages.add(
      MaxBotChatMessage(
        id: 'welcome_msg',
        isUser: false,
        text: welcomeText,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// سپر آهنین ضد پرامپت‌اینجکشن و فیلتر سوالات غیرمرتبط (Hardened Security Guardrail)
  bool _isBlockedOrOffTopicPrompt(String rawPrompt) {
    final lower = rawPrompt.toLowerCase();
    const blockedPatterns = [
      'ignore all previous',
      'ignore previous instructions',
      'system prompt',
      'developer mode',
      'jailbreak',
      'act as dan',
      'دستورات قبلی را فراموش کن',
      'پرامپت سیستم',
      'کد پایتون',
      'کد جاوا',
      'هک کردن',
      'سیاسی',
      'انتخابات',
      'ارز دیجیتال',
      'بیتکوین',
      'فیلم سینمایی',
    ];
    for (final pattern in blockedPatterns) {
      if (lower.contains(pattern)) return true;
    }
    return false;
  }

  /// مفسر هوشمند دستورات اجرایی مربی (Coach Copilot Natural Language Intent Parser)
  CoachAiActionProposal? _parseCoachOperationalCommand(String prompt) {
    if (!widget.isCoachMode) return null;
    final db = ref.read(appDatabaseProvider);
    final athletes = db.getAllActiveAthletes();
    final clean = prompt.toCleanPersian().trim();

    // ۱. دستور ارسال پیام گروهی به شاگردان منقضی یا رو به اتمام
    if ((clean.contains('منقضی') ||
            clean.contains('تموم شده') ||
            clean.contains('تمام شده') ||
            clean.contains('همه')) &&
        (clean.contains('پیام') ||
            clean.contains('اطلاع') ||
            clean.contains('بگو') ||
            clean.contains('تمدید'))) {
      final allProgs = db.getAllPrograms(includeTemplates: false);
      final Set<String> expiringIds = allProgs
          .where((p) => p.remainingDays <= 5)
          .map((p) => p.athleteId)
          .toSet();
      final targets = athletes
          .where((a) => expiringIds.contains(a.id) || expiringIds.isEmpty)
          .toList();

      if (targets.isNotEmpty) {
        return CoachAiActionProposal(
          type: CoachAiActionType.broadcastToExpiringAthletes,
          summaryTitleFa:
              'ارسال پیام یادآوری تمدید دوره به ${targets.length} ورزشکار',
          detailsFa:
              'پیام رسمی تمدید دوره در چت تلگرامی این شاگردان ثبت و ارسال می‌شود: ${targets.take(4).map((e) => e.fullName).join(" ، ")}',
          broadcastTargets: targets,
        );
      }
    }

    // جستجوی نام شاگرد داخل جمله مربی
    AthleteEntity? matchedAthlete;
    for (final a in athletes) {
      if (clean.contains(a.fullName.toCleanPersian()) ||
          (a.firstName.trim().length >= 3 &&
              clean.contains(a.firstName.toCleanPersian())) ||
          (a.lastName.trim().length >= 3 &&
              clean.contains(a.lastName.toCleanPersian()))) {
        matchedAthlete = a;
        break;
      }
    }
    if (matchedAthlete == null && athletes.length == 1) {
      matchedAthlete = athletes.first;
    }

    if (matchedAthlete == null) return null;

    // ۲. دستور تمدید برنامه شاگرد
    if (clean.contains('تمدید') || clean.contains('جدید کن')) {
      return CoachAiActionProposal(
        type: CoachAiActionType.renewAthleteProgram,
        summaryTitleFa: 'تمدید دوره ۴ هفته‌ای برای «${matchedAthlete.fullName}»',
        detailsFa:
            'تاریخ شروع برنامه شاگرد به امروز (${DateTime.now().toString().substring(0, 10)}) بروزرسانی شده و پیام اطلاع‌رسانی در چت شاگرد ارسال می‌گردد.',
        targetAthlete: matchedAthlete,
      );
    }

    // ۳. دستور تغییر هدف شاگرد (کات / حجم / عضله‌سازی خشک / تثبیت)
    if (clean.contains('هدف') ||
        clean.contains('کات') ||
        clean.contains('چربیسوزی') ||
        clean.contains('حجم') ||
        clean.contains('خشک')) {
      String newGoal = 'lean_bulk';
      String goalTitleFa = 'عضله‌سازی خشک (Lean Bulk)';
      if (clean.contains('کات') ||
          clean.contains('چربی') ||
          clean.contains('کاهش وزن')) {
        newGoal = 'weight_loss';
        goalTitleFa = 'چربیسوزی و کات (Fat Loss)';
      } else if (clean.contains('حجم') || clean.contains('افزایش وزن')) {
        newGoal = 'muscle_gain';
        goalTitleFa = 'افزایش حجم و وزن (Mass Gain)';
      } else if (clean.contains('تثبیت')) {
        newGoal = 'maintenance';
        goalTitleFa = 'تثبیت وزن (Maintenance)';
      }

      return CoachAiActionProposal(
        type: CoachAiActionType.changeAthleteGoal,
        summaryTitleFa:
            'تغییر هدف بیومتریک «${matchedAthlete.fullName}» به $goalTitleFa',
        detailsFa:
            'کالری هدف، پروتئین، کربوهیدرات و چربی روزانه شاگرد بر اساس فرمول علمی جدید به صورت خودکار بازمحاسبه می‌شود.',
        targetAthlete: matchedAthlete,
        newGoalId: newGoal,
      );
    }

    // ۴. دستور تسویه بدهی شاگرد
    if (clean.contains('تسویه') || clean.contains('پرداخت شد')) {
      return CoachAiActionProposal(
        type: CoachAiActionType.settleAthleteDebt,
        summaryTitleFa: 'تسویه کامل شهریه و بدهی «${matchedAthlete.fullName}»',
        detailsFa:
            'وضعیت مالی آخرین دوره این ورزشکار به حالت «پرداخت‌شده (Paid)» تغییر می‌یابد.',
        targetAthlete: matchedAthlete,
      );
    }

    // ۵. دستور اعمال قالب آماده روی شاگرد
    if (clean.contains('قالب')) {
      final templates = db.getSavedTemplates();
      if (templates.isNotEmpty) {
        final tpl = templates.first;
        return CoachAiActionProposal(
          type: CoachAiActionType.applyTemplateToAthlete,
          summaryTitleFa:
              'اعمال «${tpl.title.toCleanPersian()}» روی ${matchedAthlete.fullName}',
          detailsFa:
              'یک نسخه کامل از این قالب برای شاگرد ثبت شده و به صورت زنده به پرتال او ارسال می‌شود.',
          targetAthlete: matchedAthlete,
          templateToApply: tpl,
        );
      }
    }

    return null;
  }

  /// اجرای قطعی دستور مربی پس از تایید کارت پیش‌نمایش
  Future<void> _executeConfirmedCoachAction(
      int msgIndex, CoachAiActionProposal proposal) async {
    HapticFeedback.heavyImpact();
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();

    switch (proposal.type) {
      case CoachAiActionType.renewAthleteProgram:
        final ath = proposal.targetAthlete!;
        final progs = db.getProgramsForAthlete(ath.id);
        if (progs.isNotEmpty) {
          final latest = progs.first;
          final renewed = FullProgramEntity(
            id: const Uuid().v4(),
            athleteId: ath.id,
            title: '${latest.title} (تمدید شده)',
            startDate: now,
            durationWeeks: latest.durationWeeks,
            days: latest.days,
            dietMeals: latest.dietMeals,
            waterLiters: latest.waterLiters,
            dietGuidelines: latest.dietGuidelines,
            supplements: latest.supplements,
            totalFee: latest.totalFee,
            paidAmount: latest.totalFee,
            paymentStatus: 'paid',
            updatedAt: now,
          );
          db.upsertProgram(renewed);
        }
        db.insertChatMessage(ChatMessageEntity(
          id: const Uuid().v4(),
          athleteId: ath.id,
          senderRole: 'coach',
          messageText:
              '🌟 ${ath.firstName} عزیز، برنامه دوره جدیدت توسط مربی تمدید و فعال شد! پرقدرت ادامه بده 💪🔥',
          createdAt: now,
        ));
        break;

      case CoachAiActionType.changeAthleteGoal:
        final ath = proposal.targetAthlete!;
        final updatedAth = ath.copyWith(
          fitnessGoal: proposal.newGoalId ?? 'lean_bulk',
          updatedAt: now,
          syncStatus: 'pending_update',
        );
        db.upsertAthlete(updatedAth);
        break;

      case CoachAiActionType.settleAthleteDebt:
        final ath = proposal.targetAthlete!;
        final progs = db.getProgramsForAthlete(ath.id);
        for (final p in progs) {
          if (p.remainingDebt > 0) {
            db.settleProgramDebt(p.id);
          }
        }
        break;

      case CoachAiActionType.applyTemplateToAthlete:
        final ath = proposal.targetAthlete!;
        final tpl = proposal.templateToApply!;
        db.upsertProgram(FullProgramEntity(
          id: const Uuid().v4(),
          athleteId: ath.id,
          title: tpl.title.replaceAll('قالب آماده:', '').trim(),
          startDate: now,
          durationWeeks: tpl.durationWeeks,
          days: tpl.days,
          dietMeals: tpl.dietMeals,
          waterLiters: tpl.waterLiters,
          dietGuidelines: tpl.dietGuidelines,
          supplements: tpl.supplements,
          totalFee: tpl.totalFee,
          paidAmount: tpl.totalFee,
          paymentStatus: 'paid',
          isTemplate: false,
          updatedAt: now,
        ));
        break;

      case CoachAiActionType.broadcastToExpiringAthletes:
        for (final ath in proposal.broadcastTargets) {
          db.insertChatMessage(ChatMessageEntity(
            id: const Uuid().v4(),
            athleteId: ath.id,
            senderRole: 'coach',
            messageText:
                '⚡ سلام ${ath.firstName} جان، اعتبار دوره فعلی برنامه‌ات رو به اتمامه. لطفاً وزن جدیدت رو ثبت کن تا برنامه دوره جدیدت رو طراحی و تمدید کنم 🏆',
            createdAt: now,
          ));
        }
        break;
    }

    ref.read(athletesProvider.notifier).refresh();
    unawaited(ref.read(supabaseSyncServiceProvider).syncAllPendingData());

    setState(() {
      _messages[msgIndex] =
          _messages[msgIndex].copyWith(isActionExecuted: true);
    });

    if (mounted) {
      ref.read(notificationCenterProvider.notifier).pushNotification(
            eventKey: 'ai_exec_${const Uuid().v4()}',
            title: 'عملیات هوش مصنوعی اجرا شد ✅',
            body: proposal.summaryTitleFa,
            category: 'program',
            activeContext: context,
          );
    }
  }

  /// پاسخگوی علمی داخلی (در صورت آفلاین بودن یا عدم تنظیم کلید سرور)
  String _generateScientificLocalFallbackAnswer(String prompt) {
    final q = prompt.toCleanPersian().toLowerCase();
    final a = widget.currentAthlete;

    if (q.contains('پروتئین') || q.contains('وی') || q.contains('مکمل')) {
      final weight = a?.weightKg ?? 78;
      final neededProtein = (weight * 2.0).round();
      return '🧬 **پروتکل علمی مصرف پروتئین و مکمل در MAX GYM:**\n'
          '• بر اساس وزن فعلی (${weight.toStringAsFixed(0)}kg)، نیاز روزانه شما حدود **$neededProtein گرم پروتئین خالص** است.\n'
          '• **بهترین زمان مصرف وی (Whey):** ۱ اسکوپ (۳۰ گرم) بلافاصله پس از تمرین همراه با آب سرد برای سنتز سریع پروتئین عضلانی (MPS).\n'
          '• **کراتین مونوهیدرات:** روزانه ۵ گرم پس از تمرین همراه با یک وعده کربوهیدراتی و حداقل ۳.۵ لیتر آب در طول روز.';
    }

    if (q.contains('استراحت') || q.contains('ست') || q.contains('تمپو')) {
      return '⏱️ **مهندسی زمان استراحت و تمپو بین ست‌ها:**\n'
          '• **حرکات چندمفصلی سنگین (اسکات، پرس سینه، ددلیفت):** ۹۰ تا ۱۲۰ ثانیه استراحت برای بازسازی کامل ذخایر ATP-PCr.\n'
          '• **حرکات تک‌مفصلی و پمپ عضلانی (نشر جانب، جلوبازو، سیم‌کش):** ۴۵ تا ۶۰ ثانیه استراحت برای حفظ استرس متابولیک.\n'
          '• **تمپوی استاندارد عضله‌سازی (3-1-1-0):** ۳ ثانیه کنترل در بخش منفی حرکت، ۱ ثانیه مکث در کشش و ۱ ثانیه انقباض قدرتمند.';
    }

    if (q.contains('غذا') ||
        q.contains('تغذیه') ||
        q.contains('شام') ||
        q.contains('ناهار') ||
        q.contains('قبل تمرین')) {
      return '🥗 **راهنمای تغذیه قبل و بعد از تمرین (Peri-Workout Nutrition):**\n'
          '• **۹۰ دقیقه قبل از تمرین:** ترکیب کربوهیدرات پیچیده + پروتئین زودهضم (مثلاً ۶۰ گرم جو دوسر + سفیده تخم‌مرغ یا ۱ عدد موز + قهوه اسپرسو).\n'
          '• **وعده بعد از تمرین:** ۱۵۰ تا ۱۸۰ گرم سینه مرغ گریل یا فیله ماهی + ۱۵۰ گرم برنج سفید یا سیب‌زمینی تنوری (بدون چربی اضافه برای جذب سریع‌تر گلیکوژن).';
    }

    return '💪 **توصیه تخصصی MaxBot AI:**\n'
        'برای رسیدن به حداکثر هایپرتروفی عضلانی در باشگاه MAX GYM، سه اصل **اضافه‌بار تدریجی (Progressive Overload)**، دریافت کامل پروتئین روزانه و خواب عمیق ۷.۵ تا ۸ ساعته را در اولویت قرار دهید. می‌توانید رکورد هر ست را با دکمه‌های `+2.5kg` ثبت کنید تا روند پیشرفت‌تان در نمودار مربی رصد شود!';
  }

  Future<void> _submitPrompt([String? presetPrompt]) async {
    final text = (presetPrompt ?? _inputCtrl.text).trim();
    if (text.isEmpty || _isThinking) return;

    HapticFeedback.selectionClick();
    if (presetPrompt == null) _inputCtrl.clear();

    setState(() {
      _messages.add(
        MaxBotChatMessage(
          id: const Uuid().v4(),
          isUser: true,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      _isThinking = true;
    });
    _scrollToBottom();

    // ۱. بررسی سپر امنیتی ضد پرامپت‌اینجکشن
    if (_isBlockedOrOffTopicPrompt(text)) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(
          MaxBotChatMessage(
            id: const Uuid().v4(),
            isUser: false,
            text:
                '⛔ من دستیار تخصصی هوش مصنوعی باشگاه **MAX GYM** هستم و طبق منشور امنیتی فقط به سوالات علمی بدنسازی، تغذیه ورزشی، مکمل‌ها و دستورات مدیریتی مربی پاسخ می‌دهم.',
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // ۲. اگر مربی دستور عملیاتی داده است، کارت پیش‌نمایش عملیات بساز
    final coachProposal = _parseCoachOperationalCommand(text);
    if (coachProposal != null) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(
          MaxBotChatMessage(
            id: const Uuid().v4(),
            isUser: false,
            text:
                '🤖 دستور شما را تحلیل کردم. لطفاً کارت عملیات زیر را بررسی و تایید کنید تا در کل سیستم اعمال شود:',
            actionProposal: coachProposal,
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // ۳. ارسال به Supabase Edge Function امن (maxbot-ai) یا استفاده از کلید محیطی
    String? aiReply;
    final roleContext = widget.isCoachMode
        ? 'Coach Mode with ${ref.read(appDatabaseProvider).getAllActiveAthletes().length} active athletes'
        : 'Athlete: ${widget.currentAthlete?.fullName}, Weight: ${widget.currentAthlete?.weightKg}kg, Height: ${widget.currentAthlete?.heightCm}cm, Goal: ${widget.currentAthlete?.fitnessGoal}';

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        final fnRes = await client.functions.invoke(
          'maxbot-ai',
          body: {
            'prompt': text,
            'roleContext': roleContext,
            'mode': widget.isCoachMode ? 'coach_copilot' : 'scientific_qa',
            'athleteId': widget.currentAthlete?.id,
            'accessCode': widget.currentAthlete?.accessCode,
            if (envGeminiKey.isNotEmpty) 'geminiKeyOverride': envGeminiKey,
          },
        ).timeout(const Duration(seconds: 15));

        if (fnRes.status == 200 && fnRes.data is Map) {
          aiReply = fnRes.data['reply']?.toString();
        }
      }
    } catch (_) {}

    aiReply ??= _generateScientificLocalFallbackAnswer(text);

    if (!mounted) return;
    setState(() {
      _isThinking = false;
      _messages.add(
        MaxBotChatMessage(
          id: const Uuid().v4(),
          isUser: false,
          text: aiReply!,
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final quickPrompts = widget.isCoachMode
        ? [
            'به تمام شاگردان منقضی پیام تمدید بفرست',
            'برنامه مسعود مقصودی رو تمدید کن',
            'هدف مسعود رو به کات تغییر بده',
            'بهترین ترکیب مکمل برای دوران کات چیست؟',
          ]
        : [
            'بهترین وعده غذایی قبل و بعد از تمرین من چیست؟',
            'نحوه مصرف علمی کراتین و پروتئین وی چطوره؟',
            'چقدر بین ست‌های سنگین استراحت کنم؟',
          ];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.94,
      minChildSize: 0.55,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0D0C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
                color: _neuralViolet.withOpacity(0.55), width: 1.5),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_neuralViolet, Color(0xFFEC4899)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _neuralViolet.withOpacity(0.45),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(LucideIcons.sparkles,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isCoachMode
                                ? (isFa
                                    ? 'MaxBot AI • دستیار اجرایی و علمی مربی'
                                    : 'MaxBot AI • Coach Copilot')
                                : (isFa
                                    ? 'MaxBot AI • مشاور علمی تمرین و تغذیه'
                                    : 'MaxBot AI • Scientific Advisor'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isFa
                                ? 'مجهز به سپر امنیتی فیتنس + اجرای دستورات طبیعی'
                                : 'Hardened Fitness Guardrail & Action Executor',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFC084FC),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(18),
                  itemCount: _messages.length + (_isThinking ? 1 : 0),
                  itemBuilder: (ctx, idx) {
                    if (idx == _messages.length) {
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15191C),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _neuralViolet,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'MaxBot در حال پردازش علمی...',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final m = _messages[idx];
                    return Align(
                      alignment: m.isUser
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: m.isUser
                              ? _neuralViolet.withOpacity(0.28)
                              : const Color(0xFF14181A),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: m.isUser
                                ? _neuralViolet.withOpacity(0.65)
                                : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.text,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.55,
                                color: Colors.white,
                              ),
                            ),
                            if (m.actionProposal != null) ...[
                              const SizedBox(height: 12),
                              _buildActionPreviewCard(
                                  idx, m.actionProposal!, m.isActionExecuted),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: quickPrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _neuralViolet.withOpacity(0.14),
                      side: BorderSide(color: _neuralViolet.withOpacity(0.4)),
                      label: Text(
                        quickPrompts[i],
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white),
                      ),
                      onPressed: () => _submitPrompt(quickPrompts[i]),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        onSubmitted: (_) => _submitPrompt(),
                        decoration: InputDecoration(
                          hintText: widget.isCoachMode
                              ? 'دستور مدیریتی یا سوال علمی خود را بنویسید...'
                              : 'سوال علمی بدنسازی، تغذیه یا مکمل بپرسید...',
                          prefixIcon: const Icon(LucideIcons.bot,
                              color: _neuralViolet),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: _neuralViolet,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _submitPrompt(),
                      icon: const Icon(LucideIcons.send, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionPreviewCard(
      int msgIndex, CoachAiActionProposal proposal, bool isExecuted) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1311),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExecuted ? AppColors.success : const Color(0xFF72C832),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isExecuted ? LucideIcons.checkCircle2 : LucideIcons.zap,
                color: isExecuted ? AppColors.success : const Color(0xFF72C832),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  proposal.summaryTitleFa,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            proposal.detailsFa,
            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (isExecuted)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                '✅ با موفقیت در دیتابیس و پرتال شاگرد اجرا شد',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () =>
                  _executeConfirmedCoachAction(msgIndex, proposal),
              icon: const Icon(LucideIcons.checkCheck, size: 16),
              label: const Text('تایید و اجرای فوری عملیات ⚡'),
            ),
        ],
      ),
    );
  }
}
