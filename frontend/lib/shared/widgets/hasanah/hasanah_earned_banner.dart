import 'package:flutter/material.dart';

import '../../../core/utils/number_format.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../ui/ornaments.dart';

/// The hasanah a recitation earned -- ten per letter recited -- as one quiet
/// gold line with a short count-up. Celebratory, but never louder than the
/// learning on the same screen.
class HasanahEarnedBanner extends StatelessWidget {
  final int amount;
  const HasanahEarnedBanner({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$amount hasanah for the letters you recited',
      excludeSemantics: true,
      child: Row(
        children: [
          RosetteBadge(
            size: 30,
            fill: AppColors.goldWash,
            child: Icon(Icons.star_rounded, size: 14, color: AppColors.goldInk),
          ),
          const SizedBox(width: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduce ? amount.toDouble() : 0, end: amount.toDouble()),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '+${formatWithCommas(value.round())}',
              style: AppTypography.numeric(fontSize: 17, weight: FontWeight.w700, color: AppColors.goldInk),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text('hasanah for the letters you recited',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
