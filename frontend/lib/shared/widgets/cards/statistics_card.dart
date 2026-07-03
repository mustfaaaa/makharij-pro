import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'app_card.dart';

/// A labeled statistic row with a progress bar — used in the Statistics
/// screen to break down accuracy by Tajweed rule category.
class StatisticsCard extends StatelessWidget {
  final String label;
  final double percentage;
  final Color? color;

  const StatisticsCard({super.key, required this.label, required this.percentage, this.color});

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppColors.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              Text('${percentage.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: barColor)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
