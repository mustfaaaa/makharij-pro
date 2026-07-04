import 'package:flutter/material.dart';

import '../../../core/utils/number_format.dart';
import '../../../theme/app_colors.dart';

/// Reveals the hasanah just earned from a completed recitation session,
/// with a count-up animation — the moment-of-earning counterpart to
/// [HasanahCard]'s running total on the Home dashboard.
class HasanahEarnedBanner extends StatelessWidget {
  final int amount;
  const HasanahEarnedBanner({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accent.withValues(alpha: 0.20), AppColors.primary.withValues(alpha: 0.05)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: amount.toDouble()),
                    duration: const Duration(milliseconds: 1300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Text(
                      '+${formatWithCommas(value.round())} Hasanah',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                  ),
                  Text('Earned from this recitation', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
