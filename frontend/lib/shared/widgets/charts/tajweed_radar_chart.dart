import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// A custom-painted radar / spider chart of per-rule Tajweed mastery.
/// Animates the data polygon in on first build. Fully self-contained
/// (no chart package) so its look is entirely on-brand.
class TajweedRadarChart extends StatefulWidget {
  final Map<String, double> data; // label -> 0..100
  final double size;

  const TajweedRadarChart({super.key, required this.data, this.size = 220});

  @override
  State<TajweedRadarChart> createState() => _TajweedRadarChartState();
}

class _TajweedRadarChartState extends State<TajweedRadarChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _RadarPainter(
            data: widget.data,
            progress: Curves.easeOutCubic.transform(_controller.value),
            labelStyle: Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 11),
            valueStyle: (Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 11))
                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Map<String, double> data;
  final double progress;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  _RadarPainter({
    required this.data,
    required this.progress,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final labels = data.keys.toList();
    final values = data.values.toList();
    final n = labels.length;
    if (n < 3) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 34; // leave room for labels
    const start = -pi / 2;
    final step = 2 * pi / n;

    Offset vertex(int i, double frac) {
      final a = start + step * i;
      return center + Offset(cos(a), sin(a)) * radius * frac;
    }

    // Concentric grid rings.
    final gridPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ring in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = vertex(i, ring);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis spokes.
    for (int i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(i, 1.0), gridPaint);
    }

    // Data polygon (animated).
    final dataPath = Path();
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final frac = (values[i] / 100).clamp(0.0, 1.0) * progress;
      final p = vertex(i, frac);
      points.add(p);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()..color = AppColors.primary.withValues(alpha: 0.16));
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Vertex dots.
    final dotPaint = Paint()..color = AppColors.primary;
    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }

    // Labels + values at each axis.
    for (int i = 0; i < n; i++) {
      final anchor = vertex(i, 1.0);
      final a = start + step * i;
      final labelPos = center + Offset(cos(a), sin(a)) * (radius + 20);
      _drawText(canvas, labels[i], labelStyle, labelPos, center);
      _drawText(canvas, '${values[i].toStringAsFixed(0)}%', valueStyle,
          Offset.lerp(anchor, center, 0.12)! - const Offset(0, 12), center);
    }
  }

  void _drawText(Canvas canvas, String text, TextStyle style, Offset pos, Offset center) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    // Nudge horizontal alignment so left-side labels don't overrun the edge.
    final dx = pos.dx < center.dx ? -tp.width : (pos.dx > center.dx ? 0.0 : -tp.width / 2);
    tp.paint(canvas, pos + Offset(dx, -tp.height / 2));
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.data != data;
}
