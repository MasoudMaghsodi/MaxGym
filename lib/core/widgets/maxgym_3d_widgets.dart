import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ۱. کارت سهبعدی تعاملی با پرسپکتیو ماتریس 3D و درخشش نئونی (Zero-Battery Drain)
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

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final dx = (details.localPosition.dx - size.width / 2) / (size.width / 2);
    final dy = (details.localPosition.dy - size.height / 2) / (size.height / 2);
    setState(() {
      _rotateY = (dx * 0.14).clamp(-0.18, 0.18);
      _rotateX = (-dy * 0.14).clamp(-0.18, 0.18);
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
          140,
        );
        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            _resetTilt();
            widget.onTap?.call();
          },
          onTapCancel: _resetTilt,
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: (_) => _resetTilt(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            margin: widget.margin,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // عمق پرسپکتیو سهبعدی واقعی
              ..rotateX(_rotateX)
              ..rotateY(_rotateY)
              ..scale(_isPressed ? 0.97 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(_isPressed ? 0.32 : 0.14),
                  blurRadius: _isPressed ? 22 : 14,
                  spreadRadius: 1,
                  offset: Offset(-_rotateY * 25, _rotateX * 25 + 6),
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// ۲. مدل آناتومی و هیتمپ سهبعدی عضلات بدن (Interactive 3D Muscle Heatmap)
/// نمایش نمای جلو (Anterior) و پشت (Posterior) با قابلیت چرخش سهبعدی و انتخاب عضله با لمس
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
            {'id': 'shoulders', 'fa': 'سرشانه خلفی و کول', 'en': 'Rear Delts & Traps', 'top': 44.0},
            {'id': 'back', 'fa': 'زیربغل و لت (Lats)', 'en': 'Back & Lats', 'top': 86.0},
            {'id': 'triceps', 'fa': 'پشتبازو (Triceps)', 'en': 'Triceps', 'top': 96.0},
            {'id': 'legs', 'fa': 'همسترینگ و سرینی', 'en': 'Glutes & Hamstrings', 'top': 152.0},
            {'id': 'calves', 'fa': 'ساق پا (Calves)', 'en': 'Calves', 'top': 210.0},
          ]
        : [
            {'id': 'shoulders', 'fa': 'سرشانه (Deltoids)', 'en': 'Shoulders', 'top': 44.0},
            {'id': 'chest', 'fa': 'سینه (Pectorals)', 'en': 'Chest', 'top': 72.0},
            {'id': 'biceps', 'fa': 'جلوبازو و ساعد', 'en': 'Biceps & Forearms', 'top': 98.0},
            {'id': 'abs', 'fa': 'شکم و میانتنه (Core)', 'en': 'Abs & Core', 'top': 114.0},
            {'id': 'legs', 'fa': 'چهارسر ران (Quads)', 'en': 'Quadriceps', 'top': 164.0},
            {'id': 'calves', 'fa': 'ساق پا', 'en': 'Calves', 'top': 214.0},
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            primary.withOpacity(0.18),
            const Color(0xFF101412),
          ],
          radius: 0.9,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.view_in_ar_rounded, color: primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.isFa
                        ? 'هیت‌مپ سه‌بعدی آناتومی عضلات (${_showBackView ? "نمای پشت" : "نمای جلو"})'
                        : '3D Muscle Heatmap (${_showBackView ? "Posterior" : "Anterior"})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
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
          const SizedBox(height: 12),
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
                  height: 255,
                  child: Row(
                    children: [
                      // رندر سهبعدی سیلوئت بدنساز با سایهزنی حجمی و نقاط عضلانی درخشان
                      Expanded(
                        flex: 4,
                        child: CustomPaint(
                          painter: _Body3DSilhouettePainter(
                            activeMuscles: widget.activeMuscles,
                            glowColor: primary,
                            isBackView: _showBackView,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      // دکمههای سهبعدی انتخاب سریع عضلات
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
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? primary.withOpacity(0.28)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive ? primary : Colors.white12,
                                    width: isActive ? 1.8 : 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: primary.withOpacity(0.35),
                                            blurRadius: 10,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive ? primary : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.isFa
                                            ? (m['fa'] as String)
                                            : (m['en'] as String),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: Colors.white,
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
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    Paint musclePaint(String id) {
      final active = activeMuscles.contains(id);
      return Paint()
        ..color = active ? glowColor.withOpacity(0.85) : Colors.white12
        ..maskFilter =
            active ? const MaskFilter.blur(BlurStyle.normal, 4) : null;
    }

    // ۱. سر و گردن
    canvas.drawCircle(Offset(cx, 22), 14, basePaint);
    canvas.drawCircle(Offset(cx, 22), 14, outlinePaint);

    // ۲. سرشانهها (Shoulders 3D Caps)
    final leftShoulder =
        Rect.fromCenter(center: Offset(cx - 38, 52), width: 22, height: 26);
    final rightShoulder =
        Rect.fromCenter(center: Offset(cx + 38, 52), width: 22, height: 26);
    canvas.drawOval(leftShoulder, musclePaint('shoulders'));
    canvas.drawOval(rightShoulder, musclePaint('shoulders'));

    // ۳. سینه یا زیربغل (Chest / Back Lats)
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, 66), width: 54, height: 34),
      const Radius.circular(10),
    );
    canvas.drawRRect(
        torsoRect, musclePaint(isBackView ? 'back' : 'chest'));
    canvas.drawRRect(torsoRect, outlinePaint);

    // ۴. شکم و میانتنه یا فیله کمر (Abs / Lower Back)
    final coreRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, 108), width: 40, height: 42),
      const Radius.circular(8),
    );
    canvas.drawRRect(coreRect, musclePaint(isBackView ? 'back' : 'abs'));
    canvas.drawRRect(coreRect, outlinePaint);

    // ۵. بازوها (Biceps / Triceps)
    final armMuscle = isBackView ? 'triceps' : 'biceps';
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - 42, 88), width: 16, height: 44),
          const Radius.circular(8)),
      musclePaint(armMuscle),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + 42, 88), width: 16, height: 44),
          const Radius.circular(8)),
      musclePaint(armMuscle),
    );

    // ۶. رانها و سرینی (Quads / Hamstrings & Glutes)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - 14, 165), width: 22, height: 56),
          const Radius.circular(10)),
      musclePaint('legs'),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + 14, 165), width: 22, height: 56),
          const Radius.circular(10)),
      musclePaint('legs'),
    );

    // ۷. ساق پا (Calves)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - 14, 222), width: 15, height: 42),
          const Radius.circular(8)),
      musclePaint('calves'),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + 14, 222), width: 15, height: 42),
          const Radius.circular(8)),
      musclePaint('calves'),
    );
  }

  @override
  bool shouldRepaint(covariant _Body3DSilhouettePainter oldDelegate) => true;
}
