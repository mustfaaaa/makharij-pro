import 'package:flutter/material.dart';

import '../../../../models/tajweed_error.dart';
import '../../../../models/tajweed_word_info.dart';
import '../../../../services/service_locator.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';

/// What this word is: where it is articulated from, and which Tajweed rules
/// it carries.
///
/// Deliberately says nothing about how the reciter did. The results screen
/// already carries that, hedged as it has to be -- on learner voices the
/// detector wrongly flags roughly two correct recitations in five. This sheet
/// is the other half: reference data that is true no matter who is reciting,
/// so it can be stated plainly.
///
/// Opened from a flagged word on the results screen, and usable from the
/// reading page for any word at all.
class WordTajweedSheet extends StatefulWidget {
  final int surah;
  final int ayah;

  /// The app's own index: 0-based within the ayah, Basmala included.
  final int displayWordIndex;

  /// The word as the mushaf shows it, so the sheet has something to display
  /// while the lookup is in flight.
  final String displayWord;

  const WordTajweedSheet({
    super.key,
    required this.surah,
    required this.ayah,
    required this.displayWordIndex,
    required this.displayWord,
  });

  static Future<void> show(
    BuildContext context, {
    required int surah,
    required int ayah,
    required int displayWordIndex,
    required String displayWord,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => WordTajweedSheet(
        surah: surah,
        ayah: ayah,
        displayWordIndex: displayWordIndex,
        displayWord: displayWord,
      ),
    );
  }

  @override
  State<WordTajweedSheet> createState() => _WordTajweedSheetState();
}

class _WordTajweedSheetState extends State<WordTajweedSheet> {
  late final Future<TajweedWordInfo?> _lookup = Services.tajweedReference.word(
    surah: widget.surah,
    ayah: widget.ayah,
    displayWordIndex: widget.displayWordIndex,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                widget.displayWord,
                textDirection: TextDirection.rtl,
                style: AppTypography.quran(fontSize: 40, height: 1.9),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<TajweedWordInfo?>(
              future: _lookup,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  );
                }
                final info = snapshot.data;
                if (info == null) return const _NoReference();
                return _Detail(info: info);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown for a Basmala word, or on a server without the reference table.
/// Neither is an error the reciter caused, so neither is phrased as one.
class _NoReference extends StatelessWidget {
  const _NoReference();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        'No Tajweed reference for this word.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final TajweedWordInfo info;
  const _Detail({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (info.wordTransliteration.isNotEmpty)
          Center(
            child: Text(info.wordTransliteration,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: AppSpacing.lg),

        // ── Where it is articulated from ──────────────────────────────
        _Section(label: 'Articulated from'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.mdRadius,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.makhrajEnglish,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: AppColors.primaryDark)),
                    if (info.secondaryMakharij.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Also moves through ${info.secondaryMakharij.length} '
                        'other ${info.secondaryMakharij.length == 1 ? "point" : "points"}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (info.makhrajLetters.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text(info.makhrajLetters,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabicWord(
                          fontSize: 18, color: AppColors.primaryDark)),
                ),
            ],
          ),
        ),

        // ── Which rules it carries ────────────────────────────────────
        const SizedBox(height: AppSpacing.lg),
        _Section(label: 'Tajweed in this word'),
        if (info.rules.isEmpty)
          Text('No special rule applies to this word.',
              style: theme.textTheme.bodyMedium)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final rule in info.rules) _RuleChip(rule: rule, info: info)],
          ),

        if (info.maddLength > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                // "should be held" and not "you held": this number is the
                // prescription from the text, never a measurement of the
                // recording.
                child: Text(
                  'The madd should be held for about ${info.maddLength} counts.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// A rule the word carries, coloured with the same token the mushaf uses for
/// that rule, so a chip here and a marked word on the page read as one system.
class _RuleChip extends StatelessWidget {
  final String rule;
  final TajweedWordInfo info;
  const _RuleChip({required this.rule, required this.info});

  static const _labels = {
    'ghunnah': 'Ghunnah',
    'shaddah': 'Shaddah',
    'madd': 'Madd',
    'qalqalah': 'Qalqalah',
    'tafkheem': 'Tafkheem',
  };

  String? get _detail => switch (rule) {
        'ghunnah' => info.ghunnahType,
        'qalqalah' => info.qalqalahClass,
        'tafkheem' => info.tafkheemClass,
        _ => null,
      };

  Color get _color {
    final known = tajweedErrorTypeFromId(rule);
    // tafkheem and qalqalah have no detector counterpart and so no rule
    // colour; the gold ink keeps them legible without implying they belong
    // to the same set as the flagged rules.
    return known == null ? AppColors.primaryDark : TajweedRuleStyle.color(known);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_labels[rule] ?? rule,
              style: TextStyle(
                  color: _color, fontWeight: FontWeight.w700, fontSize: 12.5)),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(detail,
                style: TextStyle(
                    color: _color.withValues(alpha: 0.85), fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}
