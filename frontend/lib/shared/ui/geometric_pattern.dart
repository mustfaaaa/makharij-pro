import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An 8-fold star lattice, the most common motif in Islamic geometric
/// ornament: an eight-pointed star in every cell, joined to its neighbours
/// and to a small square at every cell corner.
///
/// Drawn, not bitmapped, so it stays sharp at every size and costs no asset.
/// It is texture, never content: use it at low [opacity] behind headers,
/// cartouches and empty states, never behind Quran text.
class GeometricPattern extends StatelessWidget {
  final Color color;
  final double opacity;
  final double cellSize;
  final double strokeWidth;

  const GeometricPattern({
    super.key,
    required this.color,
    this.opacity = 0.10,
    this.cellSize = 44,
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LatticePainter(
          color: color.withValues(alpha: opacity),
          cell: cellSize,
          stroke: strokeWidth,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  final Color color;
  final double cell;
  final double stroke;

  _LatticePainter({required this.color, required this.cell, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    final outer = cell * 0.34;
    final inner = outer * 0.56;
    final corner = cell * 0.11;
    final path = Path();

    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final c = Offset(i * cell + cell / 2, j * cell + cell / 2);
        path.addPolygon(_star(c, outer, inner), true);

        // Join the star's east and south tips to the neighbouring stars.
        path
          ..moveTo(c.dx + outer, c.dy)
          ..lineTo(c.dx + cell - outer, c.dy)
          ..moveTo(c.dx, c.dy + outer)
          ..lineTo(c.dx, c.dy + cell - outer);

        // A small square at the cell's lower-right corner, joined along the
        // diagonal to the star's south-east tip.
        final k = Offset(i * cell + cell, j * cell + cell);
        path.addRect(Rect.fromCenter(center: k, width: corner * 2, height: corner * 2));
        final tip = c + Offset(outer * math.sqrt1_2, outer * math.sqrt1_2);
        path
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(k.dx - corner, k.dy - corner);
      }
    }
    canvas.drawPath(path, paint);
  }

  static List<Offset> _star(Offset c, double r1, double r2) {
    final points = <Offset>[];
    for (var p = 0; p < 16; p++) {
      final r = p.isEven ? r1 : r2;
      final a = p * math.pi / 8;
      points.add(c + Offset(math.cos(a) * r, math.sin(a) * r));
    }
    return points;
  }

  @override
  bool shouldRepaint(_LatticePainter old) => old.color != color || old.cell != cell || old.stroke != stroke;
}
