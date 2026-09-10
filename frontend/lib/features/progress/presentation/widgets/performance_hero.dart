import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';

/// The Progress tab's headline card: overall accuracy on the Quran photo.
///
/// Sizing note -- this used to be a hard `SizedBox(height: 220)` with the
/// content laid over it by `Positioned.fill`. A fixed box cannot grow, so at
/// larger system font sizes the text simply ran past the bottom of the card
/// and Flutter reported an overflow. The card now takes 220 as a *minimum*
/// and lets its own content set the height, so the photo still fills a
/// generous card at the default text size and the card grows instead of
/// clipping when the text does.
class PerformanceHero extends StatelessWidget {
  final double overallAccuracy;
  const PerformanceHero({super.key, required this.overallAccuracy});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.lgRadius,
      child: Stack(
        children: [
          // Painted first so they sit behind the text. Being positioned, they
          // take no part in sizing the Stack -- the content below does that.
          Positioned.fill(
            child: Image.asset(
              'assets/images/quran_dark.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.35),
            ),
          ),
          // Scrim: lightest over the book so it stays prominent, deeper at
          // the edges for readable gold text.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.48),
                  ],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 220),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERFORMANCE DASHBOARD',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _AccuracyRing(overallAccuracy: overallAccuracy),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Overall Accuracy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Great progress — you’re improving steadily.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Full card width, and a Wrap rather than a Row.
                    //
                    // These pills used to sit inside the column to the right
                    // of the ring, which is only about half the card wide.
                    // "Intermediate" alone outgrows that at a large system
                    // font and pushed the row off the edge. Below the ring
                    // they get the whole card, and the Wrap lets the second
                    // pill drop to its own line rather than overflow if even
                    // that is not enough.
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [_LevelPill(), _TrendPill()],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracyRing extends StatelessWidget {
  final double overallAccuracy;
  const _AccuracyRing({required this.overallAccuracy});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: overallAccuracy / 100,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${overallAccuracy.round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  height: 1.0,
                ),
              ),
              Text(
                'accuracy',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(
            'Intermediate',
            style: TextStyle(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: AppRadii.pillRadius,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 14, color: Colors.white),
          SizedBox(width: 3),
          Text(
            '+4%',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
