import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'geometric_pattern.dart';

/// Arabic-Indic digits, so ayah numbers read the way they do in a printed
/// mushaf rather than as Latin numerals.
String arabicIndicDigits(int value) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return value.toString().split('').map((d) => digits[int.parse(d)]).join();
}

/// The illumination rosette: two interlaced squares, the eight-pointed star
/// that closes an ayah in many printed mushafs. Drawn, so it is identical in
/// every font the text might fall back to.
class RosettePainter extends CustomPainter {
  final Color stroke;
  final Color fill;
  final double strokeWidth;

  RosettePainter({required this.stroke, required this.fill, this.strokeWidth = 1.2});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2 - strokeWidth;
    final side = half * 1.42;
    final square = Rect.fromCenter(center: c, width: side, height: side);
    final r = Radius.circular(side * 0.08);

    final path = Path()..addRRect(RRect.fromRectAndRadius(square, r));
    final rotated = Path()..addRRect(RRect.fromRectAndRadius(square, r));
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(math.pi / 4)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    final star = Path.combine(PathOperation.union, path, rotated.transform(m.storage));

    canvas.drawPath(star, Paint()..color = fill);
    canvas.drawPath(
      star,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    canvas.drawCircle(
      c,
      half * 0.62,
      Paint()
        ..color = stroke.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.7,
    );
  }

  @override
  bool shouldRepaint(RosettePainter old) =>
      old.stroke != stroke || old.fill != fill || old.strokeWidth != strokeWidth;
}

/// The ayah-end marker: a gold rosette carrying the ayah number in
/// Arabic-Indic digits.
class AyahMarker extends StatelessWidget {
  final int number;
  final double size;
  const AyahMarker({super.key, required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RosettePainter(stroke: AppColors.gold, fill: AppColors.goldWash, strokeWidth: size / 26),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.06),
            child: Text(
              arabicIndicDigits(number),
              textDirection: TextDirection.rtl,
              maxLines: 1,
              style: AppTypography.arabicWord(
                fontSize: size * (number > 99 ? 0.34 : 0.42),
                color: AppColors.goldInk,
                weight: FontWeight.w700,
              ).copyWith(height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small gold rosette, for use as a bullet, a list number frame or the
/// centre of an ornamental divider.
class RosetteBadge extends StatelessWidget {
  final double size;
  final Widget? child;
  final Color? stroke;
  final Color? fill;
  const RosetteBadge({super.key, this.size = 30, this.child, this.stroke, this.fill});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RosettePainter(
          stroke: stroke ?? AppColors.gold,
          fill: fill ?? Colors.transparent,
          strokeWidth: math.max(1, size / 28),
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

/// A hairline with a small rosette at its centre: the separator between
/// sections of a page that deserve more than a plain divider.
class OrnamentDivider extends StatelessWidget {
  final double verticalPadding;
  const OrnamentDivider({super.key, this.verticalPadding = 16});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: AppColors.border));
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          children: [
            line,
            const SizedBox(width: 10),
            RosetteBadge(size: 12, fill: AppColors.goldWash),
            const SizedBox(width: 10),
            line,
          ],
        ),
      ),
    );
  }
}

/// The brand mark: the letter mīm inside a rosette, the "M" of Makharij.
class BrandMark extends StatelessWidget {
  final double size;
  final Color? color;
  const BrandMark({super.key, this.size = 56, this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MakharijPro',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: RosettePainter(
            stroke: color ?? AppColors.gold,
            fill: Colors.transparent,
            strokeWidth: math.max(1.2, size / 40),
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.only(bottom: size * 0.1),
                child: Text(
                  'م',
                  style: AppTypography.arabicWord(
                    fontSize: size * 0.46,
                    color: color ?? AppColors.primaryDark,
                    weight: FontWeight.w700,
                  ).copyWith(height: 1.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The illuminated plate above a surah's text: the surah's Arabic name inside
/// a double gold rule with rosettes at either end, over a faint star lattice.
///
/// No Basmala here: the bundled text opens ayah 1 with it (At-Tawbah
/// excepted), and a second copy would carry no recitation highlighting.
class SurahCartouche extends StatelessWidget {
  final String nameArabic;
  final String subtitle;
  final double nameSize;

  const SurahCartouche({
    super.key,
    required this.nameArabic,
    required this.subtitle,
    this.nameSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Surah $nameArabic. $subtitle',
      excludeSemantics: true,
      child: CustomPaint(
        painter: _CartouchePainter(gold: AppColors.gold, wash: AppColors.goldWash.withValues(alpha: 0.55)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned.fill(child: GeometricPattern(color: AppColors.gold, opacity: 0.10, cellSize: 34)),
              Padding(
                padding: const EdgeInsets.fromLTRB(44, 18, 44, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nameArabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabicWord(
                        fontSize: nameSize,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w700,
                      ).copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartouchePainter extends CustomPainter {
  final Color gold;
  final Color wash;
  _CartouchePainter({required this.gold, required this.wash});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    final inner = outer.deflate(4);
    canvas.drawRRect(outer, Paint()..color = wash);
    final line = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(outer, line);
    canvas.drawRRect(inner, line..strokeWidth = 0.8);

    // A rosette sitting on the centre of each short side.
    final r = math.min(12.0, size.height * 0.22);
    for (final x in [inner.left + r + 8, inner.right - r - 8]) {
      final c = Offset(x, size.height / 2);
      final rect = Rect.fromCenter(center: c, width: r * 2, height: r * 2);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      RosettePainter(stroke: gold, fill: wash, strokeWidth: 1).paint(canvas, rect.size);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CartouchePainter old) => old.gold != gold || old.wash != wash;
}
