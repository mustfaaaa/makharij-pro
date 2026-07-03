import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

/// Maps an accuracy score to a semantic color band, shared by every
/// widget that displays a Tajweed score.
Color scoreColor(double score) {
  if (score >= 90) return AppColors.scoreExcellent;
  if (score >= 75) return AppColors.scoreGood;
  if (score >= 60) return AppColors.scoreAverage;
  return AppColors.scorePoor;
}

class ScoreBadge extends StatelessWidget {
  final double score;
  final double fontSize;

  const ScoreBadge({super.key, required this.score, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadii.pillRadius),
      child: Text(
        '${score.toStringAsFixed(0)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: fontSize),
      ),
    );
  }
}
