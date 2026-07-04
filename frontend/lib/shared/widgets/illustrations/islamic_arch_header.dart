import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// A gold-line Islamic arch (mihrab-style) illustration with a crescent and
/// scattered stars — pure line art, no fill, so it works over both the light
/// cream and dark charcoal backgrounds without needing separate assets.
/// Used as the header on Login / Signup / Forgot Password.
class IslamicArchHeader extends StatelessWidget {
  final double height;
  const IslamicArchHeader({super.key, this.height = 190});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _ArchPainter(isDark: AppColors.brightness == Brightness.dark)),
    );
  }
}

class _ArchPainter extends CustomPainter {
  final bool isDark;
  _ArchPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final gold = isDark ? const Color(0xFFE0BD4A) : const Color(0xFFB08F4F);
    final goldFaint = gold.withValues(alpha: isDark ? 0.35 : 0.28);
    final cx = size.width / 2;
    final archTop = size.height * 0.10;
    final archBase = size.height * 0.92;
    final archWidth = min(size.width * 0.62, size.height * 1.15);

    // Soft glow behind the arch in dark mode only — reads as luminous gold
    // against the night charcoal; skipped in light mode to stay crisp/embossed.
    if (isDark) {
      final glowPaint = Paint()
        ..color = gold.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
      canvas.drawCircle(Offset(cx, size.height * 0.42), archWidth * 0.55, glowPaint);
    }

    // Radiating sunburst lines behind the arch, very faint — warmth/illumination cue.
    final rayPaint = Paint()
      ..color = goldFaint.withValues(alpha: goldFaint.a * 0.6)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const rays = 16;
    for (int i = 0; i < rays; i++) {
      final angle = (i / rays) * 2 * pi;
      final inner = archWidth * 0.5;
      final outer = archWidth * 0.62;
      final center = Offset(cx, size.height * 0.42);
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * inner,
        center + Offset(cos(angle), sin(angle)) * outer,
        rayPaint,
      );
    }

    // The pointed (ogee) arch outline.
    final archPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = cx - archWidth / 2;
    final right = cx + archWidth / 2;
    final shoulder = archTop + (archBase - archTop) * 0.38;

    final arch = Path()
      ..moveTo(left, archBase)
      ..lineTo(left, shoulder)
      ..quadraticBezierTo(left, archTop + 10, cx - archWidth * 0.16, archTop + 6)
      ..quadraticBezierTo(cx, archTop - 6, cx + archWidth * 0.16, archTop + 6)
      ..quadraticBezierTo(right, archTop + 10, right, shoulder)
      ..lineTo(right, archBase);
    canvas.drawPath(arch, archPaint);

    // A thin inner arch line for a layered, embossed mihrab look.
    final innerInset = archWidth * 0.09;
    final innerPaint = Paint()
      ..color = gold.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final innerArch = Path()
      ..moveTo(left + innerInset, archBase)
      ..lineTo(left + innerInset, shoulder + 6)
      ..quadraticBezierTo(left + innerInset, archTop + 20, cx - archWidth * 0.13, archTop + 16)
      ..quadraticBezierTo(cx, archTop + 6, cx + archWidth * 0.13, archTop + 16)
      ..quadraticBezierTo(right - innerInset, archTop + 20, right - innerInset, shoulder + 6)
      ..lineTo(right - innerInset, archBase);
    canvas.drawPath(innerArch, innerPaint);

    // Crescent + star centred inside the arch.
    final crescentCenter = Offset(cx, archTop + (shoulder - archTop) * 0.55);
    const crescentR = 16.0;
    final crescentPaint = Paint()..color = gold;
    canvas.drawCircle(crescentCenter, crescentR, crescentPaint);
    canvas.drawCircle(
      crescentCenter + const Offset(6, -4),
      crescentR * 0.82,
      Paint()..color = isDark ? const Color(0xFF17130E) : const Color(0xFFFBF8F3),
    );
    _drawStar(canvas, crescentCenter + const Offset(26, 8), 5, gold);

    // A light scatter of small stars either side of the arch, within the frame.
    final starSpots = [
      Offset(cx - archWidth * 0.34, archTop + 30),
      Offset(cx + archWidth * 0.30, archTop + 46),
      Offset(cx - archWidth * 0.20, archTop + 60),
      Offset(cx + archWidth * 0.14, archTop + 22),
    ];
    for (final spot in starSpots) {
      _drawStar(canvas, spot, 2.6, gold.withValues(alpha: 0.7));
    }

    // Base line grounding the arch (like a small platform/step).
    canvas.drawLine(
      Offset(left - 14, archBase),
      Offset(right + 14, archBase),
      Paint()
        ..color = gold.withValues(alpha: 0.5)
        ..strokeWidth = 1.6,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    const points = 4; // simple 4-point sparkle star
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * pi / points) - pi / 2;
      final radius = i.isEven ? r : r * 0.35;
      final p = center + Offset(cos(angle), sin(angle)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArchPainter oldDelegate) => oldDelegate.isDark != isDark;
}
