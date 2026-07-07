import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Custom pull-to-refresh. Delegates the actual drag/threshold gesture
/// handling to [RefreshIndicator.noSpinner] (battle-tested, handles both
/// platforms' overscroll semantics correctly) but replaces the default
/// Material spinner with a hand-painted rotating 8-point Islamic star that
/// matches the rest of the app's line-art illustrations.
class IslamicRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const IslamicRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<IslamicRefreshIndicator> createState() =>
      _IslamicRefreshIndicatorState();
}

class _IslamicRefreshIndicatorState extends State<IslamicRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  RefreshIndicatorStatus? _status;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  bool get _visible =>
      _status == RefreshIndicatorStatus.drag ||
      _status == RefreshIndicatorStatus.armed ||
      _status == RefreshIndicatorStatus.snap ||
      _status == RefreshIndicatorStatus.refresh;

  @override
  Widget build(BuildContext context) {
    final armed =
        _status == RefreshIndicatorStatus.armed ||
        _status == RefreshIndicatorStatus.snap ||
        _status == RefreshIndicatorStatus.refresh;
    final spinning = _status == RefreshIndicatorStatus.refresh;

    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: (status) => setState(() => _status = status),
          child: widget.child,
        ),
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedScale(
                  scale: armed ? 1.0 : 0.7,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.cardShadow, blurRadius: 8),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _spinController,
                      builder: (context, child) => Transform.rotate(
                        angle: spinning ? _spinController.value * 2 * pi : 0,
                        child: child,
                      ),
                      child: CustomPaint(painter: _IslamicStarPainter()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small 8-point star — the app's recurring Islamic sparkle motif, kept
/// consistent rather than introducing a new shape language.
class _IslamicStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final innerR = outerR * 0.42;
    const points = 8;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i / (points * 2)) * 2 * pi - pi / 2;
      final p = center + Offset(cos(angle), sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_IslamicStarPainter oldDelegate) => false;
}
