import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../buttons/primary_button.dart';

/// Tracks whether the first-time "how scoring works" coach mark has already
/// been shown this app session — in-memory only, so it reappears after a
/// full restart (no persistence layer in this prototype).
class RecitationCoachMarkFlags {
  RecitationCoachMarkFlags._();
  static bool tajweedScoringShown = false;
}

/// First-time overlay on the Recitation screen explaining how Tajweed
/// scoring works, shown once per app session before the learner's first
/// recitation attempt.
class TajweedScoringCoachMark extends StatelessWidget {
  final VoidCallback onDismiss;
  const TajweedScoringCoachMark({super.key, required this.onDismiss});

  static const _points = [
    (
      icon: Icons.mic_rounded,
      text: 'Tap the mic and recite naturally — no need to rush.',
    ),
    (
      icon: Icons.graphic_eq_rounded,
      text:
          'MakharijPro compares your recitation against correct Tajweed rules — Makharij, Ghunnah, Madd, and Shaddah.',
    ),
    (
      icon: Icons.insights_rounded,
      text: "You'll get an accuracy score and the exact words to improve.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: Colors.black.withValues(alpha: 0.6),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                // Swallow taps on the card itself so they don't dismiss.
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.all(AppSpacing.screenPadding),
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'How Tajweed Scoring Works',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final p in _points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(p.icon, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.text,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(label: 'Got it', onPressed: onDismiss),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
