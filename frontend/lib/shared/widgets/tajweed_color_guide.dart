import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// The signature colour for each Tajweed rule, reused by the legend, the
/// colour-coded verse, and (ideally) the feedback badges.
Map<String, Color> get tajweedRuleColors => {
  'Makhraj': AppColors.info,
  'Ghunnah': AppColors.accent,
  'Shaddah': AppColors.warning,
  'Madd': AppColors.primary,
  'Qalqalah': AppColors.error,
};

/// A legend + a small colour-coded sample ayah, like a real Tajweed mushaf,
/// so learners can see how each rule is highlighted.
class TajweedColorGuide extends StatelessWidget {
  const TajweedColorGuide({super.key});

  // Sample words mapped to the rule they illustrate.
  static const List<(String, String)> _sample = [
    ('بِسْمِ', 'Makhraj'),
    ('اللَّهِ', 'Shaddah'),
    ('الرَّحْمَٰنِ', 'Ghunnah'),
    ('الرَّحِيمِ', 'Madd'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colour-coded verse
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            textDirection: TextDirection.rtl,
            spacing: 10,
            runSpacing: 8,
            children: _sample
                .map((e) => Text(e.$1, style: AppTypography.arabicVerse(fontSize: 26, color: tajweedRuleColors[e.$2])))
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Legend
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: tajweedRuleColors.entries.map((e) => _LegendChip(label: e.key, color: e.value)).toList(),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
