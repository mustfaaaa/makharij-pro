import 'package:flutter/material.dart';

import '../../../../shared/ui/geometric_pattern.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_typography.dart';

/// The Progress tab's headline: the average share of recited words that
/// matched the expected recitation, and nothing it cannot back up.
///
/// It used to say "Great progress -- you're improving steadily", "Intermediate"
/// and "+4%" whatever the numbers were, even at 0% with no sessions. All three
/// were fixed strings. This states the one measured figure and what it means.
///
/// Sizing: 220 is a *minimum* and the content sets the height, so at larger
/// system text sizes the panel grows instead of clipping its own text.
class PerformanceHero extends StatelessWidget {
  final double overallAccuracy;
  final int? totalSessions;
  const PerformanceHero({super.key, required this.overallAccuracy, this.totalSessions});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = overallAccuracy.clamp(0, 100).round();
    final ink = AppColors.textOnBrandCard;
    return Semantics(
      label: 'On average, $pct percent of the words you recited matched the expected recitation'
          '${totalSessions == null ? '' : ', across $totalSessions sessions'}.',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadii.lgRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.brandCardGradient,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: GeometricPattern(color: ink, opacity: 0.07, cellSize: 42)),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 220),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        _Ring(value: pct / 100, label: '$pct%'),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Words matched, on average',
                                  style: textTheme.titleMedium?.copyWith(color: ink)),
                              const SizedBox(height: 6),
                              Text(
                                'The share of the words you recited that matched their expected pronunciation.',
                                style: textTheme.bodySmall?.copyWith(color: ink.withValues(alpha: 0.82)),
                              ),
                              if (totalSessions != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Across $totalSessions recitation${totalSessions == 1 ? '' : 's'}',
                                  style: textTheme.labelMedium?.copyWith(color: AppColors.gold),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double value;
  final String label;
  const _Ring({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 96,
      height: 96,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? value : 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                color: AppColors.gold,
                backgroundColor: AppColors.textOnBrandCard.withValues(alpha: 0.14),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(label, style: AppTypography.numeric(fontSize: 24, color: AppColors.textOnBrandCard)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
