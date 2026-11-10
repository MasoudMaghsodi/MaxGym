import 'package:flutter/material.dart';
import '../../core/config/maxgym_brand_config.dart';

class MaxGym3DSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const MaxGym3DSplashScreen({super.key, required this.nextScreen});

  @override
  State<MaxGym3DSplashScreen> createState() => _MaxGym3DSplashScreenState();
}

class _MaxGym3DSplashScreenState extends State<MaxGym3DSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotateYAnim;
  bool _showNext = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _rotateYAnim = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showNext = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showNext) return widget.nextScreen;

    const venomGreen = Color(0xFF72C832);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D0B),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              venomGreen.withOpacity(0.24),
              const Color(0xFF0A0D0B),
            ],
            radius: 0.85,
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateY(_rotateYAnim.value)
                    ..scale(_scaleAnim.value),
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: venomGreen, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: venomGreen.withOpacity(0.45),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        MaxGymBrandConfig.bundledLogoAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.fitness_center,
                          size: 90,
                          color: venomGreen,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  MaxGymBrandConfig.appName,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: venomGreen,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  MaxGymBrandConfig.appSlogan,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    color: venomGreen,
                    backgroundColor: Colors.white12,
                    minHeight: 4,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
