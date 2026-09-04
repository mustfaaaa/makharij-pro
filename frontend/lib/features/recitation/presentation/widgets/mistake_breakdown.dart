import 'package:flutter/material.dart';

import '../../../../models/tajweed_error.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/tajweed_rule_style.dart';

/// How many mistakes of each rule this recitation contained, at a glance.
///
/// The per-word marking answers "where"; this answers "what am I actually weak
/// at", which is the thing worth acting on. Reading eight scattered red words
/// and noticing that six of them are elongations is work the screen should do
/// for the reciter.
///
/// Rules with no mistakes are shown at zero rather than hidden: a clean rule is
/// information too, and a row that changes shape between sessions is harder to
/// compare against last time.
class MistakeBreakdown extends StatelessWidget {
  final Map<TajweedErrorType, int> counts;

  /// [skipped] words are counted separately from mispronounced ones and only
  /// appear when there are any -- an empty "0 skipped" on every clean run is
  /// noise, since skipping is not a pronunciation weakness to train.
  static const _always = [
    TajweedErrorType.madd,
    TajweedErrorType.ghunnah,
    TajweedErrorType.shaddah,
    TajweedErrorType.makhraj,
  ];

  const MistakeBreakdown({super.key, required this.counts});

  /// Tally of the rules broken, ready to hand to this widget.
  static Map<TajweedErrorType, int> tally(Iterable<TajweedErrorType?> types) {
    final counts = <TajweedErrorType, int>{};
    for (final type in types) {
      if (type != null) counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final shown = [
      ..._always,
      if ((counts[TajweedErrorType.skipped] ?? 0) > 0) TajweedErrorType.skipped,
    ];

    return Row(
      children: [
        for (final rule in shown) ...[
          Expanded(child: _Tile(rule: rule, count: counts[rule] ?? 0)),
          if (rule != shown.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final TajweedErrorType rule;
  final int count;
  const _Tile({required this.rule, required this.count});

  @override
  Widget build(BuildContext context) {
    final none = count == 0;
    final color = none ? AppColors.textMuted : TajweedRuleStyle.color(rule);

    return Semantics(
      label: '$count ${rule.label} mistake${count == 1 ? '' : 's'}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text('$count',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700, height: 1.15)),
            Text(
              rule.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 9.5, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
