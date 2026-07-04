import 'package:flutter/material.dart';

/// A hand-painted open Qur'an (mushaf) — cream pages with a gold bookmark
/// ribbon, drawn to sit in white/cream tones so it reads clearly against a
/// dark gold gradient card (per the "Start Reading" card).
class OpenMushafIllustration extends StatelessWidget {
  final double size;
  const OpenMushafIllustration({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _MushafPainter()));
  }
}

class _MushafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final spine = Offset(w / 2, h * 0.32);

    final pageFill = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final pageShade = Paint()..color = Colors.white.withValues(alpha: 0.62);
    final lineStroke = Paint()
      ..color = const Color(0xFF9C7A3E)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Left page (slightly foreshortened, as if seen from a gentle angle).
    final left = Path()
      ..moveTo(spine.dx, spine.dy)
      ..quadraticBezierTo(w * 0.14, h * 0.30, w * 0.06, h * 0.42)
      ..lineTo(w * 0.08, h * 0.86)
      ..quadraticBezierTo(w * 0.30, h * 0.94, spine.dx, h * 0.86)
      ..close();
    canvas.drawPath(left, pageShade);

    // Right page (drawn on top, brighter — the "active" page).
    final right = Path()
      ..moveTo(spine.dx, spine.dy)
      ..quadraticBezierTo(w * 0.86, h * 0.30, w * 0.94, h * 0.42)
      ..lineTo(w * 0.92, h * 0.86)
      ..quadraticBezierTo(w * 0.70, h * 0.94, spine.dx, h * 0.86)
      ..close();
    canvas.drawPath(right, pageFill);

    // Spine shadow line.
    canvas.drawLine(spine, Offset(spine.dx, h * 0.86), Paint()
      ..color = const Color(0xFF9C7A3E).withValues(alpha: 0.4)
      ..strokeWidth = 1.2);

    // Faint text lines on the right (open) page — suggests Arabic script
    // without literally rendering any, so it reads at any size.
    for (int i = 0; i < 4; i++) {
      final y = h * 0.48 + i * (h * 0.09);
      final xStart = spine.dx + w * 0.06;
      final xEnd = w * 0.86 - (i.isEven ? 0 : w * 0.08);
      canvas.drawLine(Offset(xStart, y), Offset(xEnd, y), lineStroke..strokeWidth = 1.1);
    }
    // A couple of matching lines on the left page, fainter.
    final lineStrokeFaint = Paint()
      ..color = const Color(0xFF9C7A3E).withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final y = h * 0.50 + i * (h * 0.10);
      canvas.drawLine(Offset(w * 0.12, y), Offset(spine.dx - w * 0.06, y), lineStrokeFaint);
    }

    // Gold bookmark ribbon draped over the spine.
    final ribbon = Path()
      ..moveTo(spine.dx - 5, h * 0.20)
      ..lineTo(spine.dx + 5, h * 0.20)
      ..lineTo(spine.dx + 5, h * 0.40)
      ..lineTo(spine.dx, h * 0.34)
      ..lineTo(spine.dx - 5, h * 0.40)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = const Color(0xFFE8D48A));
  }

  @override
  bool shouldRepaint(_MushafPainter oldDelegate) => false;
}
