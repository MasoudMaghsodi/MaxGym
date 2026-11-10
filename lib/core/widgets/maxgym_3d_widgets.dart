import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// ۱. کارت سهبعدی تعاملی با پرسپکتیو ماتریس 3D، نورپردازی استودیویی و درخشش نئونی
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
      _rotateY = (dx * 0.12).clamp(-0.16, 0.16);
      _rotateX = (-dy * 0.12).clamp(-0.16, 0.16);
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
                ..scale(_isPressed ? 0.97 : (_isHovered ? 1.015 : 1.0)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(
                        _isPressed ? 0.36 : (_isHovered ? 0.26 : 0.14)),
                    blurRadius: _isHovered ? 28 : 18,
                    spreadRadius: _isHovered ? 2 : 0,
                    offset: Offset(-_rotateY * 22, _rotateX * 22 + 8),
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

/// ۲. کارت شیشهای بنتو (Bento Glassmorphic Card) با خط نوری بالای کارت و هاله نئونی
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
    this.borderRadius = 24,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  glow.withOpacity(0.14),
                  const Color(0xFF141B17).withOpacity(0.92),
                  const Color(0xFF0D120F).withOpacity(0.96),
                ]
              : [
                  Colors.white,
                  glow.withOpacity(0.06),
                ],
        ),
        border: Border.all(
          color: isDark ? glow.withOpacity(0.32) : glow.withOpacity(0.25),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? glow.withOpacity(0.10) : Colors.black12,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              // خط نوری استودیویی در لبه بالای کارت (Top Specular Highlight)
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(isDark ? 0.35 : 0.6),
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
      ),
    );
  }
}

/// ۳. حلقههای نئونی سهگانه ماکرو و کالری (Apple Fitness+ / Whoop Style Macro Rings)
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
    final totalCalFromMacros =
        (proteinGrams * 4) + (carbsGrams * 4) + (fatGrams * 9);
    final safeTotal = totalCalFromMacros > 0 ? totalCalFromMacros : 2000;

    final pRatio = ((proteinGrams * 4) / safeTotal).clamp(0.15, 0.85);
    final cRatio = ((carbsGrams * 4) / safeTotal).clamp(0.15, 0.85);
    final fRatio = ((fatGrams * 9) / safeTotal).clamp(0.15, 0.85);

    return MaxGymGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 135,
            height: 135,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, _) {
                return CustomPaint(
                  painter: _ConcentricMacroRingsPainter(
                    proteinProgress: pRatio * animValue,
                    carbsProgress: cRatio * animValue,
                    fatProgress: fRatio * animValue,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: Color(0xFF72C832), size: 20),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '$targetCalories',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          isFa ? 'کیلوکالری هدف' : 'TARGET KCAL',
                          style: const TextStyle(
                              fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _macroLegendRow(
                  color: const Color(0xFFFF3B5C),
                  label: isFa ? 'پروتئین عضلهساز' : 'Protein',
                  grams: '${proteinGrams}g',
                  kcal: '${proteinGrams * 4} kcal',
                ),
                const SizedBox(height: 10),
                _macroLegendRow(
                  color: const Color(0xFFFFB800),
                  label: isFa ? 'کربوهیدرات انرژی' : 'Net Carbs',
                  grams: '${carbsGrams}g',
                  kcal: '${carbsGrams * 4} kcal',
                ),
                const SizedBox(height: 10),
                _macroLegendRow(
                  color: const Color(0xFFB84DFF),
                  label: isFa ? 'چربیهای ضروری' : 'Healthy Fats',
                  grams: '${fatGrams}g',
                  kcal: '${fatGrams * 9} kcal',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroLegendRow({
    required Color color,
    required String label,
    required String grams,
    required String kcal,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.6), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$grams ($kcal)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcentricMacroRingsPainter extends CustomPainter {
  final double proteinProgress;
  final double carbsProgress;
  final double fatProgress;

  _ConcentricMacroRingsPainter({
    required this.proteinProgress,
    required this.carbsProgress,
    required this.fatProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 10.5;

    void drawRing(double radius, double progress, Color color) {
      final bgPaint = Paint()
        ..color = color.withOpacity(0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, bgPaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.05, 0.98),
        false,
        fgPaint,
      );
    }

    drawRing(size.width / 2 - 6, proteinProgress, const Color(0xFFFF3B5C));
    drawRing(size.width / 2 - 20, carbsProgress, const Color(0xFFFFB800));
    drawRing(size.width / 2 - 34, fatProgress, const Color(0xFFB84DFF));
  }

  @override
  bool shouldRepaint(covariant _ConcentricMacroRingsPainter oldDelegate) =>
      true;
}

/// ۴. گیج طیفی مدرن برای نمایش بصری BMI و WHtR
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
                      color: Colors.grey),
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
          const SizedBox(height: 10),
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
                    height: 8,
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
                        border: Border.all(color: Colors.black, width: 2),
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
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// ۵. مدل آناتومی و هیتمپ سهبعدی عضلات بدن با فیزیک واقعی V-Taper (Pro-Bezier Vector Anatomy)
class Interactive3DMuscleAnatomy extends StatefulWidget {
  final List<String> activeMuscles; // ['chest', 'biceps', 'legs', ...]
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
    extends State<Interactive3DMuscleAnatomy>
    with SingleTickerProviderStateMixin {
  bool _showBackView = false;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _flip3DBody() {
    if (_showBackView) {
      _spinCtrl.reverse();
    } else {
      _spinCtrl.forward();
    }
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
            },
            {
              'id': 'back',
              'fa': 'زیربغل و لت (Lats)',
              'en': 'Back & Lats',
            },
            {
              'id': 'triceps',
              'fa': 'پشتبازو (Triceps)',
              'en': 'Triceps',
            },
            {
              'id': 'legs',
              'fa': 'همسترینگ و سرینی',
              'en': 'Glutes & Hamstrings',
            },
            {
              'id': 'calves',
              'fa': 'ساق پا (Calves)',
              'en': 'Calves',
            },
          ]
        : [
            {
              'id': 'shoulders',
              'fa': 'سرشانه (Deltoids)',
              'en': 'Shoulders',
            },
            {
              'id': 'chest',
              'fa': 'سینه (Pectorals)',
              'en': 'Chest',
            },
            {
              'id': 'biceps',
              'fa': 'جلوبازو و ساعد',
              'en': 'Biceps & Forearms',
            },
            {
              'id': 'abs',
              'fa': 'شکم و میانتنه (Core)',
              'en': 'Abs & Core',
            },
            {
              'id': 'legs',
              'fa': 'چهارسر ران (Quads)',
              'en': 'Quadriceps',
            },
            {
              'id': 'calves',
              'fa': 'ساق پا',
              'en': 'Calves',
            },
          ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            primary.withOpacity(0.22),
            const Color(0xFF101713),
            const Color(0xFF0A0E0C),
          ],
          radius: 1.0,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.42), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Icon(Icons.view_in_ar_rounded, color: primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.isFa
                            ? 'هیت‌مپ سه‌بعدی آناتومی عضلات (${_showBackView ? "نمای پشت" : "نمای جلو"})'
                            : '3D Muscle Heatmap (${_showBackView ? "Posterior" : "Anterior"})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _flip3DBody,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.threed_rotation, size: 16),
                label: Text(widget.isFa ? 'چرخش 3D بدن' : 'Rotate 3D'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _spinCtrl,
            builder: (context, child) {
              final angle = _spinCtrl.value * math.pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle > math.pi / 2 ? angle - math.pi : angle),
                child: SizedBox(
                  height: 270,
                  child: Row(
                    children: [
                      // رندر وکتور آناتومیک بدنساز V-Taper با خطوط اسکنر سایبرنتیک
                      Expanded(
                        flex: 5,
                        child: CustomPaint(
                          painter: _Body3DSilhouettePainter(
                            activeMuscles: widget.activeMuscles,
                            glowColor: primary,
                            isBackView: _showBackView,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // دکمههای کپسولی انتخاب سریع عضلات
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: muscleNodes.map((m) {
                            final id = m['id'] as String;
                            final isActive = widget.activeMuscles.contains(id);
                            return GestureDetector(
                              onTap: () => widget.onMuscleTapped?.call(id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? LinearGradient(
                                          colors: [
                                            primary.withOpacity(0.35),
                                            primary.withOpacity(0.12),
                                          ],
                                        )
                                      : null,
                                  color: isActive
                                      ? null
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive ? primary : Colors.white12,
                                    width: isActive ? 1.8 : 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: primary.withOpacity(0.38),
                                            blurRadius: 12,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive ? primary : Colors.grey,
                                        boxShadow: isActive
                                            ? [
                                                BoxShadow(
                                                  color: primary,
                                                  blurRadius: 6,
                                                )
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        widget.isFa
                                            ? (m['fa'] as String)
                                            : (m['en'] as String),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isActive
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Body3DSilhouettePainter extends CustomPainter {
  final List<String> activeMuscles;
  final Color glowColor;
  final bool isBackView;

  _Body3DSilhouettePainter({
    required this.activeMuscles,
    required this.glowColor,
    required this.isBackView,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // ۱. رسم شبکه هولوگرافیک سایبرنتیک پشت کاراکتر
    final gridPaint = Paint()
      ..color = glowColor.withOpacity(0.08)
      ..strokeWidth = 1;
    for (double y = 20; y < size.height; y += 28) {
      canvas.drawLine(
          Offset(cx - 75, y), Offset(cx + 75, y), gridPaint);
    }
    canvas.drawCircle(
      Offset(cx, size.height / 2),
      88,
      Paint()
        ..color = glowColor.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    Paint fillFor(String id) {
      final active = activeMuscles.contains(id);
      return Paint()
        ..color = active
            ? glowColor.withOpacity(0.88)
            : const Color(0xFF25302B).withOpacity(0.75)
        ..style = PaintingStyle.fill;
    }

    void drawMusclePath(Path path, String id) {
      final active = activeMuscles.contains(id);
      if (active) {
        canvas.drawPath(
          path,
          Paint()
            ..color = glowColor.withOpacity(0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
      }
      canvas.drawPath(path, fillFor(id));
      canvas.drawPath(path, outlinePaint);
    }

    // ۲. سر و گردن آناتومیک
    final headPath = Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, 22), width: 24, height: 28));
    canvas.drawPath(
        headPath, Paint()..color = const Color(0xFF2C3832));
    canvas.drawPath(headPath, outlinePaint);

    // عضله کول (Traps) و گردن
    final trapsPath = Path()
      ..moveTo(cx - 8, 34)
      ..lineTo(cx + 8, 34)
      ..lineTo(cx + 26, 44)
      ..lineTo(cx - 26, 44)
      ..close();
    drawMusclePath(trapsPath, 'shoulders');

    // ۳. سرشانههای گرد سهبعدی (Deltoids - Left & Right)
    final leftDelt = Path()
      ..moveTo(cx - 26, 44)
      ..quadraticBezierTo(cx - 50, 46, cx - 48, 66)
      ..quadraticBezierTo(cx - 38, 72, cx - 30, 62)
      ..close();
    final rightDelt = Path()
      ..moveTo(cx + 26, 44)
      ..quadraticBezierTo(cx + 50, 46, cx + 48, 66)
      ..quadraticBezierTo(cx + 38, 72, cx + 30, 62)
      ..close();
    drawMusclePath(leftDelt, 'shoulders');
    drawMusclePath(rightDelt, 'shoulders');

    // ۴. سینه تفکیکشده (Pectorals) یا زیربغل V-Taper (Back Lats)
    if (!isBackView) {
      final leftPec = Path()
        ..moveTo(cx - 2, 45)
        ..lineTo(cx - 26, 45)
        ..quadraticBezierTo(cx - 32, 64, cx - 24, 76)
        ..lineTo(cx - 2, 74)
        ..close();
      final rightPec = Path()
        ..moveTo(cx + 2, 45)
        ..lineTo(cx + 26, 45)
        ..quadraticBezierTo(cx + 32, 64, cx + 24, 76)
        ..lineTo(cx + 2, 74)
        ..close();
      drawMusclePath(leftPec, 'chest');
      drawMusclePath(rightPec, 'chest');
    } else {
      final backLats = Path()
        ..moveTo(cx - 26, 45)
        ..lineTo(cx + 26, 45)
        ..quadraticBezierTo(cx + 34, 75, cx + 18, 118)
        ..lineTo(cx - 18, 118)
        ..quadraticBezierTo(cx - 34, 75, cx - 26, 45)
        ..close();
      drawMusclePath(backLats, 'back');
    }

    // ۵. سیکسپک شکم و میانتنه (Abs & Obliques)
    if (!isBackView) {
      final corePath = Path()
        ..moveTo(cx - 22, 78)
        ..lineTo(cx + 22, 78)
        ..lineTo(cx + 17, 130)
        ..lineTo(cx - 17, 130)
        ..close();
      drawMusclePath(corePath, 'abs');
      // خطوط تفکیک سیکسپک
      canvas.drawLine(Offset(cx, 78), Offset(cx, 128), outlinePaint);
      canvas.drawLine(Offset(cx - 19, 94), Offset(cx + 19, 94), outlinePaint);
      canvas.drawLine(Offset(cx - 18, 110), Offset(cx + 18, 110), outlinePaint);
    } else {
      final lowerBack = Path()
        ..moveTo(cx - 17, 118)
        ..lineTo(cx + 17, 118)
        ..lineTo(cx + 20, 136)
        ..lineTo(cx - 20, 136)
        ..close();
      drawMusclePath(lowerBack, 'back');
    }

    // ۶. بازوها و ساعدهای عضلانی (Biceps / Triceps & Forearms)
    final armMuscle = isBackView ? 'triceps' : 'biceps';
    final leftArm = Path()
      ..moveTo(cx - 46, 66)
      ..quadraticBezierTo(cx - 54, 88, cx - 48, 118)
      ..lineTo(cx - 36, 118)
      ..quadraticBezierTo(cx - 30, 88, cx - 32, 64)
      ..close();
    final rightArm = Path()
      ..moveTo(cx + 46, 66)
      ..quadraticBezierTo(cx + 54, 88, cx + 48, 118)
      ..lineTo(cx + 36, 118)
      ..quadraticBezierTo(cx + 30, 88, cx + 32, 64)
      ..close();
    drawMusclePath(leftArm, armMuscle);
    drawMusclePath(rightArm, armMuscle);

    // ۷. چهارسر ران و همسترینگ (Quads / Hamstrings)
    final leftQuad = Path()
      ..moveTo(cx - 20, 134)
      ..lineTo(cx - 3, 134)
      ..quadraticBezierTo(cx - 2, 172, cx - 7, 198)
      ..lineTo(cx - 22, 198)
      ..quadraticBezierTo(cx - 30, 165, cx - 20, 134)
      ..close();
    final rightQuad = Path()
      ..moveTo(cx + 20, 134)
      ..lineTo(cx + 3, 134)
      ..quadraticBezierTo(cx + 2, 172, cx + 7, 198)
      ..lineTo(cx + 22, 198)
      ..quadraticBezierTo(cx + 30, 165, cx + 20, 134)
      ..close();
    drawMusclePath(leftQuad, 'legs');
    drawMusclePath(rightQuad, 'legs');

    // ۸. ساق پاهای الماسی (Diamond Calves)
    final leftCalf = Path()
      ..moveTo(cx - 21, 202)
      ..lineTo(cx - 8, 202)
      ..quadraticBezierTo(cx - 5, 224, cx - 10, 252)
      ..lineTo(cx - 19, 252)
      ..quadraticBezierTo(cx - 26, 224, cx - 21, 202)
      ..close();
    final rightCalf = Path()
      ..moveTo(cx + 21, 202)
      ..lineTo(cx + 8, 202)
      ..quadraticBezierTo(cx + 5, 224, cx + 10, 252)
      ..lineTo(cx + 19, 252)
      ..quadraticBezierTo(cx + 26, 224, cx + 21, 202)
      ..close();
    drawMusclePath(leftCalf, 'calves');
    drawMusclePath(rightCalf, 'calves');
  }

  @override
  bool shouldRepaint(covariant _Body3DSilhouettePainter oldDelegate) => true;
}
