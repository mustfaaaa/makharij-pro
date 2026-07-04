import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Tiles a subtle 8-pointed Islamic star pattern behind [child].
/// [opacity] 0.03–0.05 recommended so it reads as texture, not wallpaper.
class IslamicPatternBackground extends StatelessWidget {
  final Widget child;
  final double opacity;

  const IslamicPatternBackground({
    super.key,
    required this.child,
    this.opacity = 0.04,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.background),
        Opacity(
          opacity: opacity,
          child: CustomPaint(
            painter: _IslamicTilePainter(),
            size: Size.infinite,
          ),
        ),
        child,
      ],
    );
  }
}

class _IslamicTilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const cell = 64.0;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final cx = col * cell + (row.isOdd ? cell / 2 : 0);
        final cy = row * cell;
        _drawStar(canvas, paint, Offset(cx, cy), cell * 0.38);
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double r) {
    const pts = 8;
    const inner = 0.45;
    final path = Path();
    for (var i = 0; i < pts * 2; i++) {
      final angle = (i * math.pi / pts) - math.pi / 2;
      final radius = i.isEven ? r : r * inner;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
