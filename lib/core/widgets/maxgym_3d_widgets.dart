import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// ۱. کارت سه‌بعدی تعاملی با پرسپکتیو نرم، شیدر هولوگرافیک و بازخورد لمسی (Shneiderman Visceral Feedback)
class MaxGym3DTiltCard extends StatefulWidget {
  final Widget child;
  final Color? glowColor;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const MaxGym3DTiltCard({
    super.key,
    required this.child,
    this.glowColor,
    this.margin,
    this.onTap,
  });

  @override
  State<MaxGym3DTiltCard> createState() => _MaxGym3DTiltCardState();
}

class _MaxGym3DTiltCardState extends State<MaxGym3DTiltCard> {
  double _rotateX = 0.0;
  double _rotateY = 0.0;
  bool _isPressed = false;
  bool _isHovered = false;

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final dx = (details.localPosition.dx - size.width / 2) / (size.width / 2);
    final dy = (details.localPosition.dy - size.height / 2) / (size.height / 2);
    setState(() {
      _rotateY = (dx * 0.10).clamp(-0.14, 0.14);
      _rotateX = (-dy * 0.10).clamp(-0.14, 0.14);
    });
  }

  void _resetTilt() {
    setState(() {
      _rotateX = 0.0;
      _rotateY = 0.0;
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.glowColor ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 300,
          150,
        );
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) {
            setState(() => _isHovered = false);
            _resetTilt();
          },
          child: GestureDetector(
            onTapDown: (_) {
              HapticFeedback.selectionClick();
              setState(() => _isPressed = true);
            },
            onTapUp: (_) {
              _resetTilt();
              widget.onTap?.call();
            },
            onTapCancel: _resetTilt,
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: (_) => _resetTilt(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: widget.margin,
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateX(_rotateX)
                ..rotateY(_rotateY)
                ..scale(_isPressed ? 0.97 : (_isHovered ? 1.015 : 1.0)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? accent.withOpacity(0.26)
                        : Colors.black.withOpacity(0.50),
                    blurRadius: _isHovered ? 30 : 20,
                    offset: Offset(-_rotateY * 18, _rotateX * 18 + 10),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// ۲. کارت شیشه مات ابسیدین (Smoked Obsidian Glass - منطبق بر اثر Von Restorff برای عدم خستگی چشم)
class MaxGymGlassCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool isHighlighted;

  const MaxGymGlassCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 26,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glow = accentColor ?? theme.colorScheme.primary;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDark ? const Color(0xFF111513) : Colors.white,
        border: Border.all(
          color: isHighlighted
              ? glow.withOpacity(0.65)
              : (isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.06)),
          width: isHighlighted ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? glow.withOpacity(0.18)
                : (isDark ? Colors.black.withOpacity(0.48) : Colors.black12),
            blurRadius: isHighlighted ? 26 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            if (isDark)
              Positioned(
                top: -45,
                right: -45,
                child: IgnorePointer(
                  child: Container(
                    width: 135,
                    height: 135,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glow.withOpacity(isHighlighted ? 0.20 : 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 32,
              right: 32,
              child: Container(
                height: 1.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(isDark ? 0.18 : 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// ۳. جزیره پویای تایمر استراحت با رنگ روانشناختی کرایو (Cryo Dynamic Rest Island)
class MaxGymDynamicRestIsland extends StatelessWidget {
  final int remainingSeconds;
  final VoidCallback onAdd15Seconds;
  final VoidCallback onSkipRest;
  final bool isFa;

  const MaxGymDynamicRestIsland({
    super.key,
    required this.remainingSeconds,
    required this.onAdd15Seconds,
    required this.onSkipRest,
    this.isFa = true,
  });

  @override
  Widget build(BuildContext context) {
    if (remainingSeconds <= 0) return const SizedBox.shrink();

    const cryoCyan = Color(0xFF00F0FF);
    const urgentAmber = Color(0xFFFF8A00);
    final isFinalCountdown = remainingSeconds <= 5;
    final activeTone = isFinalCountdown ? urgentAmber : cryoCyan;

    // راهنمای ریتم تنفس ۴ ثانیه‌ای برای کاهش ضربان قلب بین ست‌ها
    final inhalePhase = (remainingSeconds ~/ 4) % 2 == 0;
    final breathText = isFinalCountdown
        ? (isFa ? '🔥 آماده شروع ست بعدی باش!' : '🔥 GET READY FOR NEXT SET!')
        : (inhalePhase
            ? (isFa ? '❄️ دم عمیق از بینی (۴ ثانیه)...' : '❄️ Inhale deeply...')
            : (isFa ? '💨 بازدم آرام از دهان...' : '💨 Exhale slowly...'));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF090E10),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: activeTone.withOpacity(0.75), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: activeTone.withOpacity(0.28),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeTone.withOpacity(0.16),
              border: Border.all(color: activeTone, width: 1.5),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${remainingSeconds}s',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: activeTone,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isFa
                      ? 'ریکاوری فعال بین ست‌ها'
                      : 'Active Inter-Set Recovery',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  breathText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: activeTone,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onAdd15Seconds();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.08),
              minimumSize: const Size(48, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: Text('+15s',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: isFa ? 'رد کردن استراحت' : 'Skip Rest',
            onPressed: () {
              HapticFeedback.mediumImpact();
              onSkipRest();
            },
            icon: const Icon(LucideIcons.fastForward,
                size: 18, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// ۴. نمایشگر بصری سه‌بعدی صفحه‌های هالتر المپیکی (3D Visual Barbell Plate Calculator)
class MaxGym3DBarbellPlateModal extends StatefulWidget {
  final double initialTotalWeightKg;
  final bool isFa;

  const MaxGym3DBarbellPlateModal({
    super.key,
    required this.initialTotalWeightKg,
    this.isFa = true,
  });

  static void show(BuildContext context,
      {required double weightKg, required bool isFa}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D110F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => MaxGym3DBarbellPlateModal(
        initialTotalWeightKg: weightKg > 20 ? weightKg : 60,
        isFa: isFa,
      ),
    );
  }

  @override
  State<MaxGym3DBarbellPlateModal> createState() =>
      _MaxGym3DBarbellPlateModalState();
}

class _MaxGym3DBarbellPlateModalState extends State<MaxGym3DBarbellPlateModal> {
  late double _totalWeight;
  double _barWeight = 20.0;

  @override
  void initState() {
    super.initState();
    _totalWeight = widget.initialTotalWeightKg.clamp(20.0, 340.0);
  }

  List<double> _calculatePlatesPerSide() {
    double rem = ((_totalWeight - _barWeight) / 2.0).clamp(0.0, 200.0);
    const availablePlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
    final List<double> result = [];
    for (final p in availablePlates) {
      while (rem >= p - 0.01) {
        result.add(p);
        rem -= p;
      }
    }
    return result;
  }

  Color _plateColor(double weight) {
    if (weight == 25.0) return const Color(0xFFEF4444); // المپیکی قرمز
    if (weight == 20.0) return const Color(0xFF2563EB); // المپیکی آبی
    if (weight == 15.0) return const Color(0xFFEAB308); // المپیکی زرد
    if (weight == 10.0) return const Color(0xFF10B981); // المپیکی سبز
    if (weight == 5.0) return const Color(0xFFF8FAFC); // سفید
    if (weight == 2.5) return const Color(0xFF64748B); // ذغالی
    return const Color(0xFF94A3B8); // کروم ۱.۲۵
  }

  double _plateHeight(double weight) {
    if (weight >= 20.0) return 112;
    if (weight == 15.0) return 96;
    if (weight == 10.0) return 82;
    if (weight == 5.0) return 66;
    return 52;
  }

  @override
  Widget build(BuildContext context) {
    final isFa = widget.isFa;
    final primary = Theme.of(context).colorScheme.primary;
    final plates = _calculatePlatesPerSide();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.dumbbell, color: primary),
                  const SizedBox(width: 10),
                  Text(
                    isFa
                        ? 'راهنمای بصری چیدن صفحه‌های هالتر'
                        : '3D Olympic Barbell Plate Loader',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Chip(
                  backgroundColor: primary.withOpacity(0.18),
                  label: Text(
                    '${_totalWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // شبیه‌ساز بصری میله هالتر استیل و صفحه‌های المپیکی هر طرف
          Container(
            height: 145,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF141916),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // میله استیل هالتر
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF475569),
                        Color(0xFFCBD5E1),
                        Color(0xFF334155),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // صفحه‌های سوارشده روی یک سمت هالتر
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // یقه استیل نگهدارنده هالتر
                    Container(
                      width: 14,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF94A3B8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (plates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          isFa ? 'فقط میله خالی هالتر' : 'Empty Barbell Only',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      )
                    else
                      ...plates.map((w) {
                        final c = _plateColor(w);
                        return Container(
                          width: w >= 15 ? 24 : 18,
                          height: _plateHeight(w),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: c.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              w % 1 == 0 ? '${w.toInt()}' : '$w',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color:
                                    w == 5.0 ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            plates.isEmpty
                ? (isFa
                    ? 'میله استاندارد ${_barWeight.toInt()} کیلوگرمی بدون صفحه اضافه'
                    : '${_barWeight.toInt()}kg Bar Only')
                : (isFa
                    ? 'در هر طرف هالتر (${_barWeight.toInt()}kg) این صفحه‌ها را قرار دهید: ${plates.map((e) => "${e % 1 == 0 ? e.toInt() : e}kg").join(" + ")}'
                    : 'Each side (${_barWeight.toInt()}kg bar): ${plates.map((e) => "${e}kg").join(" + ")}'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() =>
                      _totalWeight = (_totalWeight - 2.5).clamp(20.0, 340.0));
                },
                icon: const Icon(LucideIcons.minus, size: 16),
                label: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('-2.5 kg'),
                ),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(isFa ? 'هالتر ۲۰kg' : '20kg Bar'),
                selected: _barWeight == 20.0,
                onSelected: (_) => setState(() => _barWeight = 20.0),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(isFa ? 'هالتر ۱۵kg' : '15kg Bar'),
                selected: _barWeight == 15.0,
                onSelected: (_) => setState(() => _barWeight = 15.0),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() =>
                      _totalWeight = (_totalWeight + 2.5).clamp(20.0, 340.0));
                },
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('+2.5 kg'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ۵. گیج نیم‌دایره مدرج با پشتیبانی از اثر پیشرفت اعطاشده (Endowed Progress Effect)
class MaxGymDashedArcGauge extends StatelessWidget {
  final double progress;
  final String centerValue;
  final String subtitle;
  final Color? activeColor;

  const MaxGymDashedArcGauge({
    super.key,
    required this.progress,
    required this.centerValue,
    required this.subtitle,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = activeColor ?? Theme.of(context).colorScheme.primary;
    // طبق کتاب Universal Principles of Design، تیک اول همیشه به صورت نیمه‌روشن (Warm-up Ready) نمایش داده می‌شود
    final effectiveVisualProgress = math.max(0.06, progress.clamp(0.0, 1.0));

    return SizedBox(
      height: 125,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: effectiveVisualProgress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animVal, _) {
          return CustomPaint(
            painter: _DashedSemiArcPainter(
              progress: animVal,
              activeColor: primary,
            ),
            child: Align(
              alignment: const Alignment(0, 0.45),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      centerValue,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashedSemiArcPainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  _DashedSemiArcPainter({
    required this.progress,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.88);
    final radius = math.min(size.width * 0.40, size.height * 0.80);
    const totalTicks = 42;
    final activeTicks = (totalTicks * progress).round();

    for (int i = 0; i <= totalTicks; i++) {
      final t = i / totalTicks;
      final angle = math.pi + (t * math.pi);
      final isLit = i <= activeTicks && progress > 0;

      final innerR = radius - 10;
      final outerR = radius;

      final p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );

      final paint = Paint()
        ..color = isLit ? activeColor : Colors.white.withOpacity(0.12)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedSemiArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ۶. ستون‌های عمودی تغذیه و ماکرو
class MaxGymNeonMacroRings extends StatelessWidget {
  final int targetCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final bool isFa;

  const MaxGymNeonMacroRings({
    super.key,
    required this.targetCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.isFa = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _verticalNutritionPillar(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF5E3A),
            title: isFa ? 'کالری هدف' : 'Calories',
            mainValue: '$targetCalories',
            unit: 'Kcal',
            subValue: isFa ? 'روزانه' : 'Daily Target',
            fillRatio: 0.82,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _verticalNutritionPillar(
            icon: Icons.scatter_plot_rounded,
            iconColor: const Color(0xFF00C2FF),
            title: isFa ? 'پروتئین' : 'Proteins',
            mainValue: '$proteinGrams',
            unit: 'g',
            subValue: '${proteinGrams * 4} Kcal',
            fillRatio: 0.75,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _verticalNutritionPillar(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFFFB800),
            title: isFa ? 'کربوهیدرات' : 'Carbs',
            mainValue: '$carbsGrams',
            unit: 'g',
            subValue: '${carbsGrams * 4} Kcal',
            fillRatio: 0.68,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _verticalNutritionPillar(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFFB84DFF),
            title: isFa ? 'چربی مفید' : 'Fats',
            mainValue: '$fatGrams',
            unit: 'g',
            subValue: '${fatGrams * 9} Kcal',
            fillRatio: 0.45,
          ),
        ),
      ],
    );
  }

  Widget _verticalNutritionPillar({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String mainValue,
    required String unit,
    required String subValue,
    required double fillRatio,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141715),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white60,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: mainValue,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '/ $subValue',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white38,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillRatio,
              minHeight: 4,
              backgroundColor: Colors.white10,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// ۷. گیج طیفی مدرن برای نمایش بصری BMI و WHtR
class MaxGymSpectrumGauge extends StatelessWidget {
  final String title;
  final String valueText;
  final String statusText;
  final double normalizedPosition;
  final Color accentColor;

  const MaxGymSpectrumGauge({
    super.key,
    required this.title,
    required this.valueText,
    required this.statusText,
    required this.normalizedPosition,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return MaxGymGlassCard(
      accentColor: accentColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white60),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final dotLeft =
                  (normalizedPosition.clamp(0.05, 0.95) * barWidth) - 7;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00E5FF),
                          Color(0xFF72C832),
                          Color(0xFFFFB800),
                          Color(0xFFFF2A54),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: dotLeft,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.9),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// ۸. پنل انتخابگر رادیویی عضلات هدف
class Interactive3DMuscleAnatomy extends StatefulWidget {
  final List<String> activeMuscles;
  final void Function(String muscleId)? onMuscleTapped;
  final bool isFa;

  const Interactive3DMuscleAnatomy({
    super.key,
    required this.activeMuscles,
    this.onMuscleTapped,
    this.isFa = true,
  });

  @override
  State<Interactive3DMuscleAnatomy> createState() =>
      _Interactive3DMuscleAnatomyState();
}

class _Interactive3DMuscleAnatomyState
    extends State<Interactive3DMuscleAnatomy> {
  bool _showBackView = false;

  void _flip3DBody() {
    HapticFeedback.selectionClick();
    setState(() => _showBackView = !_showBackView);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final muscleNodes = _showBackView
        ? [
            {
              'id': 'shoulders',
              'fa': 'سرشانه خلفی و کول',
              'en': 'Rear Delts & Traps',
              'zone': 'UPPER POSTERIOR',
            },
            {
              'id': 'back',
              'fa': 'زیربغل و لت (Lats)',
              'en': 'Back & Lats',
              'zone': 'MID POSTERIOR',
            },
            {
              'id': 'triceps',
              'fa': 'پشتبازو (Triceps)',
              'en': 'Triceps',
              'zone': 'ARM EXTENSORS',
            },
            {
              'id': 'legs',
              'fa': 'همسترینگ و سرینی',
              'en': 'Glutes & Hamstrings',
              'zone': 'LOWER POSTERIOR',
            },
            {
              'id': 'calves',
              'fa': 'ساق پا (Calves)',
              'en': 'Calves',
              'zone': 'GASTROCNEMIUS',
            },
          ]
        : [
            {
              'id': 'shoulders',
              'fa': 'سرشانه (Deltoids)',
              'en': 'Shoulders',
              'zone': 'ANTERIOR DELT',
            },
            {
              'id': 'chest',
              'fa': 'سینه (Pectorals)',
              'en': 'Chest',
              'zone': 'PECTORALIS MAJOR',
            },
            {
              'id': 'biceps',
              'fa': 'جلوبازو و ساعد',
              'en': 'Biceps & Forearms',
              'zone': 'ARM FLEXORS',
            },
            {
              'id': 'abs',
              'fa': 'شکم و میان‌تنه (Core)',
              'en': 'Abs & Core',
              'zone': 'RECTUS ABDOMINIS',
            },
            {
              'id': 'legs',
              'fa': 'چهارسر ران (Quads)',
              'en': 'Quadriceps',
              'zone': 'QUADRICEPS FEMORIS',
            },
            {
              'id': 'calves',
              'fa': 'ساق پا',
              'en': 'Calves',
              'zone': 'SOLEUS / CALF',
            },
          ];

    return MaxGymGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(Icons.radar_rounded, color: primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          widget.isFa
                              ? 'هیت‌مپ سه‌بعدی آناتومی عضلات (${_showBackView ? "نمای پشت" : "نمای جلو"})'
                              : '3D Muscle Heatmap (${_showBackView ? "Posterior" : "Anterior"})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _flip3DBody,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withOpacity(0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(
                  widget.isFa ? 'چرخش 3D بدن' : 'Rotate 3D',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: muscleNodes.map((m) {
              final id = m['id'] as String;
              final isActive = widget.activeMuscles.contains(id);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onMuscleTapped?.call(id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 165,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? primary.withOpacity(0.14)
                        : const Color(0xFF1B1F1D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive
                          ? primary
                          : Colors.white.withOpacity(0.06),
                      width: isActive ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? primary : Colors.transparent,
                          border: Border.all(
                            color: isActive ? primary : Colors.white24,
                            width: 2,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: primary.withOpacity(0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: isActive
                            ? Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isFa
                                  ? (m['fa'] as String)
                                  : (m['en'] as String),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color:
                                    isActive ? Colors.white : Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                m['zone'] as String,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isActive ? primary : Colors.white38,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
