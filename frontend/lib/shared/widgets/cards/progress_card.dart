import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'app_card.dart';

/// A single metric card with a big number and a trend label —
/// used across the home dashboard and progress screens.
class ProgressCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? trend;
  final bool trendUp;

  const ProgressCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              if (trend != null)
                Row(
                  children: [
                    Icon(trendUp ? Icons.trending_up : Icons.trending_down, size: 14, color: trendUp ? AppColors.success : AppColors.error),
                    const SizedBox(width: 2),
                    Text(trend!, style: TextStyle(fontSize: 11, color: trendUp ? AppColors.success : AppColors.error)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
