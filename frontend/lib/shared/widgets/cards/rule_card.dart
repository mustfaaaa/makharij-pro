import 'package:flutter/material.dart';

import '../../../models/tajweed_rule.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import 'app_card.dart';

class RuleCard extends StatelessWidget {
  final TajweedRule rule;
  final VoidCallback? onTap;

  const RuleCard({super.key, required this.rule, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(rule.arabicExample, style: AppTypography.arabicWord(fontSize: 16), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(rule.title, style: Theme.of(context).textTheme.titleSmall)),
                    if (rule.isBookmarked) const Icon(Icons.bookmark, size: 16, color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 4),
                Text(rule.shortDescription, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
