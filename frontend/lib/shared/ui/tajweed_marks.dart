import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/tajweed_error.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/tajweed_rule_style.dart';

/// How the app talks about a flagged word: a patient teacher, not a red
/// "WRONG". The headline names what to look at; the body is the backend's own
/// explanation whenever it sent one, and these fallbacks only fill a gap.
abstract class TajweedCopy {
  static String headline(TajweedErrorType? rule) {
    switch (rule) {
      case TajweedErrorType.madd:
        return 'Review this Madd';
      case TajweedErrorType.ghunnah:
        return 'Ghunnah may need more hold';
      case TajweedErrorType.shaddah:
        return 'Review the Shaddah';
      case TajweedErrorType.makhraj:
        return 'Makhraj needs attention';
      case TajweedErrorType.skipped:
        return "This word wasn't heard";
      case null:
        return 'Check this pronunciation';
    }
  }

  static String fallbackBody(TajweedErrorType? rule) {
    switch (rule) {
      case TajweedErrorType.madd:
        return 'The elongation may need its full count.';
      case TajweedErrorType.ghunnah:
        return 'Hold the nasal sound for about two counts.';
      case TajweedErrorType.shaddah:
        return 'This letter should sound doubled.';
      case TajweedErrorType.makhraj:
        return 'A letter may be off its point of articulation.';
      case TajweedErrorType.skipped:
        return 'Did you recite it? Try the ayah again.';
      case null:
        return 'This word sounded different from what was expected.';
    }
  }
}

/// A short drawn sample of a rule's underline -- dashed, wavy, double,
/// dotted, struck -- so a rule is named by shape as well as colour wherever it
/// appears outside the Quran text.
class RuleShapeSwatch extends StatelessWidget {
  final TajweedErrorType rule;
  final double width;
  final Color? color;
  const RuleShapeSwatch({super.key, required this.rule, this.width = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, 10),
        painter: _SwatchPainter(rule, color ?? TajweedRuleStyle.color(rule)),
      ),
    );
  }
}

/// A single Quran word shown on its own, with its rule's shape drawn as a
/// separate mark beneath it. A text underline sits wherever the Quran font's
/// deep descent puts it -- often through whatever comes next -- so standalone
/// words draw the mark themselves, exactly the word's width.
class MarkedWord extends StatelessWidget {
  final String word;
  final TajweedErrorType? rule;
  final Color color;
  final double fontSize;
  const MarkedWord({super.key, required this.word, required this.rule, required this.color, this.fontSize = 26});

  @override
  Widget build(BuildContext context) {
    final mark = rule;
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            word,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.quran(fontSize: fontSize, color: color, height: 1.7),
          ),
          if (mark != null)
            ExcludeSemantics(
              child: CustomPaint(size: const Size.fromHeight(10), painter: _SwatchPainter(mark, color)),
            ),
        ],
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  final TajweedErrorType rule;
  final Color color;
  _SwatchPainter(this.rule, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    switch (rule) {
      case TajweedErrorType.madd:
        for (double x = 0; x < size.width; x += 7) {
          canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), p);
        }
      case TajweedErrorType.ghunnah:
        final path = Path()..moveTo(0, y);
        for (double x = 0; x <= size.width; x += 1) {
          path.lineTo(x, y + math.sin(x / size.width * 4 * math.pi) * 2.4);
        }
        canvas.drawPath(path, p);
      case TajweedErrorType.shaddah:
        p.strokeWidth = 1.5;
        canvas.drawLine(Offset(0, y - 2), Offset(size.width, y - 2), p);
        canvas.drawLine(Offset(0, y + 2), Offset(size.width, y + 2), p);
      case TajweedErrorType.makhraj:
        final dot = Paint()..color = color;
        for (double x = 1.5; x < size.width; x += 5) {
          canvas.drawCircle(Offset(x, y), 1.4, dot);
        }
      case TajweedErrorType.skipped:
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.rule != rule || old.color != color;
}

/// A rule named in a pill: its shape, its name and optionally a count.
class RuleChip extends StatelessWidget {
  final TajweedErrorType rule;
  final int? count;
  final bool compact;
  const RuleChip({super.key, required this.rule, this.count, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = TajweedRuleStyle.color(rule);
    final label = count == null ? rule.label : '${rule.label} $count';
    return Semantics(
      label: count == null ? rule.label : '$count ${rule.label} to review',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 5 : 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppColors.brightness == Brightness.dark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RuleShapeSwatch(rule: rule, width: compact ? 16 : 20),
            SizedBox(width: compact ? 6 : 8),
            Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
