import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/number_format.dart';
import '../../../theme/app_colors.dart';
import '../feedback/app_dialogs.dart';

/// Home-screen card showing the learner's accumulated hasanah (reward)
/// count, animated as a count-up on first build. Tapping the info icon
/// explains the concept — each letter of Qur'an recitation earns ten
/// hasanah, per the hadith (Tirmidhi 2910).
class HasanahCard extends StatelessWidget {
  final int count;
  const HasanahCard({super.key, required this.count});

  void _showInfo(BuildContext context) {
    AppDialogs.info(
      context,
      title: 'What is a Hasanah?',
      message:
          'The Prophet ﷺ said: "Whoever reads a letter from the Book of Allah, '
          'he will have a reward. And that reward will be multiplied by ten." '
          '(Tirmidhi 2910)\n\n'
          'Every letter you recite in MakharijPro adds ten hasanah to your total — '
          'a small, ongoing reminder of the reward behind your practice.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const _TasbihMotif(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Hasanah Earned',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showInfo(context),
                      child: Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _CountUpNumber(target: count),
                const SizedBox(height: 2),
                Text(
                  'Every letter recited = 10 hasanah',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small hand-painted string of prayer beads (tasbih) — the on-theme
/// alternative to a generic star/trophy icon.
class _TasbihMotif extends StatelessWidget {
  const _TasbihMotif();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: CustomPaint(painter: _TasbihPainter()),
    );
  }
}

class _TasbihPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final strandPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius, strandPaint);

    const beadCount = 10;
    for (int i = 0; i < beadCount; i++) {
      final angle = (i / beadCount) * 2 * pi - pi / 2;
      final beadCenter = center + Offset(cos(angle), sin(angle)) * radius;
      final isImam = i == 0; // the larger "imam" bead marking a full cycle
      canvas.drawCircle(
        beadCenter,
        isImam ? 5.5 : 3.6,
        Paint()..color = isImam ? AppColors.accent : AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(_TasbihPainter oldDelegate) => false;
}

class _CountUpNumber extends StatelessWidget {
  final int target;
  const _CountUpNumber({required this.target});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: const Offset(-8, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withValues(alpha: 0.24), AppColors.accent.withValues(alpha: 0.0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              formatWithCommas(value.round()),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
                height: 1.1,
              ),
            ),
          ),
        );
      },
    );
  }
}
