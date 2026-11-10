import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ۱. کارت سهبعدی تعاملی با پرسپکتیو نرم و سایه عمیق استودیویی
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
            onTapDown: (_) => setState(() => _isPressed = true),
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
                ..scale(_isPressed ? 0.97 : (_isHovered ? 1.012 : 1.0)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? accent.withOpacity(0.22)
                        : Colors.black.withOpacity(0.45),
                    blurRadius: _isHovered ? 28 : 20,
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

/// ۲. کارت مات مخملی (Matte Obsidian Card - به سبک عکس ۲ و ۳ بدون کادرهای سبز شلوغ)
class MaxGymGlassCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const MaxGymGlassCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 26,
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
        color: isDark ? const Color(0xFF141715) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.065)
              : Colors.black.withOpacity(0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.45) : Colors.black12,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // هاله بسیار ظریف نقطهای در گوشه بالا-راست (فقط ۸٪ شفافیت برای حفظ سادگی مات)
            if (isDark)
              Positioned(
                top: -45,
                right: -45,
                child: IgnorePointer(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glow.withOpacity(0.11),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // خط بازتاب نور استودیویی بسیار ظریف در سقف کارت
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
                      Colors.white.withOpacity(isDark ? 0.16 : 0.5),
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

/// ۳. گیج نیمدایره مدرج خطچین (Dashed Semi-Circle Progress Arc - دقیقاً مثل عکس ۱ راست)
class MaxGymDashedArcGauge extends StatelessWidget {
  final double progress; // 0.0 to 1.0
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
    return SizedBox(
      height: 125,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
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

/// ۴. کارتهای عمودی تغذیه و ماکرو به سبک تصویر ۲ (`Your Daily Nutrition`: Calories, Proteins, Carbs, Fats)
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
    return Column(
      children: [
        Row(
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

/// ۵. گیج طیفی مدرن برای نمایش بصری BMI و WHtR
class MaxGymSpectrumGauge extends StatelessWidget {
  final String title;
  final String valueText;
  final String statusText;
  final double normalizedPosition; // 0.0 to 1.0
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

/// ۶. پنل انتخابگر رادیویی عضلات هدف (به سبک تصویر ۳ - Target Muscles با حذف کامل آدمک کارتونی)
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
              'fa': 'شکم و میانتنه (Core)',
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
                      child: Icon(Icons.radar_rounded, color: primary, size: 18),
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
          // کارتهای انتخابگر رادیویی عضلات به سبک تصویر ۳ (fitonist - Target muscles)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: muscleNodes.map((m) {
              final id = m['id'] as String;
              final isActive = widget.activeMuscles.contains(id);
              return GestureDetector(
                onTap: () => widget.onMuscleTapped?.call(id),
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
                      // حلقه رادیویی نئونی دقیقاً مثل عکس ۳ (fitonist)
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
