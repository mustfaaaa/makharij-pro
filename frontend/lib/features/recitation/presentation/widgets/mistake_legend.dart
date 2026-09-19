import 'package:flutter/material.dart';

import '../../../../models/tajweed_error.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/tajweed_rule_style.dart';
import '../../../../shared/ui/tajweed_marks.dart';

/// Says what the colours and underlines under the verse mean.
///
/// Without it the marking is a puzzle: the reader can see that two words are
/// marked differently but not that one was a short elongation and the other a
/// missed nasal hum. It also states plainly that these mark *mistakes*, not
/// the Tajweed rules present in the verse — a coloured mushaf marks every
/// place a rule applies, and a reader used to one would otherwise read this
/// page backwards.
class MistakeLegend extends StatelessWidget {
  /// Only the rules actually present in this result, so a clean recitation
  /// isn't handed a legend for mistakes it didn't make.
  final Set<TajweedErrorType> rules;

  /// Whether to explain the greyed-out text as well.
  final bool showNotRecited;

  const MistakeLegend({super.key, required this.rules, this.showNotRecited = false});

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty && !showNotRecited) return const SizedBox.shrink();

    // Keep a stable order rather than whatever order the mistakes happened in.
    final ordered = TajweedErrorType.values.where(rules.contains).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final rule in ordered) _LegendChip(rule: rule),
            if (showNotRecited) const _NotRecitedChip(),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'These mark words to review, not every Tajweed rule in the verse.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final TajweedErrorType rule;
  const _LegendChip({required this.rule});

  @override
  Widget build(BuildContext context) {
    // The same shape the verse uses, drawn on a blank sample so the shape is
    // what the reader matches on, not the word underneath it.
    return Semantics(
      label: '${rule.label}, shown ${TajweedRuleStyle.shapeHint(rule)}',
      excludeSemantics: true,
      child: RuleChip(rule: rule, compact: true),
    );
  }
}

class _NotRecitedChip extends StatelessWidget {
  const _NotRecitedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Not recited',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
