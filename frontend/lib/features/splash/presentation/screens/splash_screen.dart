import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Choreographed in phases so the mark, the drawn flourish, and the text
  // arrive in sequence rather than all at once.
  late final Animation<double> _markScale; // 0.00 - 0.40
  late final Animation<double> _markFade;
  late final Animation<double> _haloFade;
  late final Animation<double> _flourish; // 0.35 - 0.80 (stroke draw-on)
  late final Animation<double> _textFade; // 0.60 - 1.00
  late final Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _markScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)),
    );
    _markFade = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3, curve: Curves.easeOut));
    _haloFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.55, curve: Curves.easeOut)),
    );
    _flourish = CurvedAnimation(parent: _controller, curve: const Interval(0.35, 0.8, curve: Curves.easeInOut));
    _textFade = CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOut));
    _textSlide = Tween(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    _controller.forward();
    Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      context.go(Services.auth.currentUser != null ? RoutePaths.home : RoutePaths.onboarding);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mark: glowing halo + scaling meem
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: _haloFade.value * 0.5,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [AppColors.accentLight.withValues(alpha: 0.6), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: _markFade.value,
                        child: Transform.scale(
                          scale: _markScale.value,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text('م', style: AppTypography.arabicVerse(fontSize: 44, color: AppColors.primary)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Calligraphic flourish that draws itself
                SizedBox(
                  width: 200,
                  height: 26,
                  child: CustomPaint(painter: _FlourishPainter(progress: _flourish.value)),
                ),
                const SizedBox(height: 16),
                // Wordmark + tagline slide up
                Transform.translate(
                  offset: Offset(0, _textSlide.value),
                  child: Opacity(
                    opacity: _textFade.value,
                    child: Column(
                      children: [
                        Text(
                          'MakharijPro AI',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Perfect your Tajweed, one word at a time',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
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

/// Draws a symmetric calligraphic swash stroke that reveals from the centre
/// outward as [progress] goes 0 -> 1, using PathMetrics to extract a partial
/// length of the stroke (the "ink drawing on" effect).
class _FlourishPainter extends CustomPainter {
  final double progress;
  _FlourishPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path()
      ..moveTo(cx, cy)
      // right half: gentle wave out to a small end curl
      ..relativeCubicTo(24, -14, 46, 12, 70, -2)
      ..relativeCubicTo(10, -6, 18, -2, 20, 6);
    // mirror for the left half
    final left = Path()
      ..moveTo(cx, cy)
      ..relativeCubicTo(-24, -14, -46, 12, -70, -2)
      ..relativeCubicTo(-10, -6, -18, -2, -20, 6);
    path.addPath(left, Offset.zero);

    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }

    // A small centre gem that fades in with the stroke.
    final dotPaint = Paint()..color = AppColors.accentLight.withValues(alpha: progress);
    canvas.drawCircle(Offset(cx, cy), 2.4, dotPaint);
  }

  @override
  bool shouldRepaint(_FlourishPainter oldDelegate) => oldDelegate.progress != progress;
}
