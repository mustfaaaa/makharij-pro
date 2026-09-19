import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';

/// The first frame: the brand mark settling on parchment, then straight on.
///
/// It used to play a fixed two-second animation on every launch. It now hands
/// off as soon as the mark has arrived, and sends someone who has already
/// seen onboarding to Welcome rather than through it again.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
      _timer = Timer(Duration(milliseconds: reduce ? 250 : 900), _next);
    });
  }

  void _next() {
    if (!mounted) return;
    final String next;
    if (Services.auth.currentUser != null) {
      next = RoutePaths.home;
    } else if (Services.prefs.onboardingSeen) {
      next = RoutePaths.welcome;
    } else {
      next = RoutePaths.onboarding;
    }
    context.go(next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: GeometricPattern(color: AppColors.gold, opacity: 0.06, cellSize: 56)),
          Center(
            child: FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(curve),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 96),
                    const SizedBox(height: 18),
                    Text('MakharijPro', style: AppTypography.displayText(fontSize: 34)),
                    const SizedBox(height: 4),
                    Text('Recite. Understand. Improve.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
