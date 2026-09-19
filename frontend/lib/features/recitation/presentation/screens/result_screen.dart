import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../features/quran/presentation/widgets/mushaf_ayah.dart';
import '../../../../models/ayah.dart';
import '../../../../models/session_result.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../models/tajweed_word_info.dart';
import '../../../../models/word_verdict.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/tajweed_marks.dart';
import '../../../../shared/widgets/hasanah/hasanah_earned_banner.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';
import '../bloc/recitation_cubit.dart';
import '../widgets/mistake_legend.dart';
import '../widgets/reference_playback_button.dart';
import '../widgets/said_it_right_button.dart';
import '../widgets/try_word_again_button.dart';
import '../widgets/word_playback_button.dart';

/// The results of a recitation, laid out like a patient teacher going over it
/// with you: what matched, what went well, what to look at, where it is in the
/// passage, and a way to try again.
///
/// It reports a *count* of words that matched, never a grade: the detector
/// wrongly flags roughly two correct recitations in five (ml/eval/README.md),
/// so the screen states what was measured and claims nothing more, and every
/// flag can be overruled.
class ResultScreen extends StatefulWidget {
  final int surahNumber;
  const ResultScreen({super.key, required this.surahNumber});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _hasanahCredited = false;

  void _done() {
    context.read<RecitationCubit>().reset();
    context.go(RoutePaths.home);
  }

  void _tryAgain(SessionResult result) {
    // Back to the same reading page recitation started from, with the same
    // range -- there is only one place to recite.
    final from = result.fromAyah;
    final to = result.toAyah;
    context.read<RecitationCubit>().beginSession(widget.surahNumber);
    context.pushReplacement(RoutePaths.surahDetailsPath(widget.surahNumber, from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    final recitationState = context.watch<RecitationCubit>().state;
    final result = recitationState.result;
    final ayahs = recitationState.selectedAyahs;
    if (result == null) {
      // A direct deep-link without a recitation behind it.
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: EmptyStateWidget(
          icon: Icons.mic_none_rounded,
          title: 'No recitation to show',
          message: 'Results appear here after you recite. Pick a surah and begin.',
          actionLabel: 'Choose a surah',
          onAction: () => context.go(RoutePaths.quran),
        ),
      );
    }

    if (!_hasanahCredited) {
      _hasanahCredited = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<HasanahCubit>().addHasanah(result.hasanahEarned);
      });
    }

    final surah = dummySurahs.where((s) => s.number == widget.surahNumber).firstOrNull;
    final verdicts = result.wordVerdicts;
    final from = ayahs.isEmpty ? result.fromAyah : ayahs.first.number;
    final to = ayahs.isEmpty ? result.toAyah : ayahs.last.number;
    final range = from == null ? '' : (to == null || to == from ? 'Ayah $from' : 'Ayahs $from–$to');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.screenPadding,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(surah?.nameEnglish ?? result.surahName, style: Theme.of(context).textTheme.titleMedium),
            if (range.isNotEmpty)
              Text(range, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          // The flow arrives via pushReplacement, so there is no back stack to
          // pop -- an explicit way home.
          IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: _done),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: verdicts != null && verdicts.isNotEmpty
                ? _VerdictResults(
                    result: result,
                    ayahs: ayahs,
                    verdicts: verdicts,
                    surahNumber: widget.surahNumber,
                  )
                : _ErrorListResults(result: result, surahNumber: widget.surahNumber),
          ),
          _ActionBar(onTryAgain: () => _tryAgain(result), onDone: _done),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onDone;
  const _ActionBar({required this.onTryAgain, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onTryAgain,
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  label: const Text('Try again'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: onDone, child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Word-level results ───────────────────────────────────────────────────────

class _VerdictResults extends StatelessWidget {
  final SessionResult result;
  final List<Ayah> ayahs;
  final List<WordVerdict> verdicts;
  final int surahNumber;

  const _VerdictResults({
    required this.result,
    required this.ayahs,
    required this.verdicts,
    required this.surahNumber,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recited = verdicts.where((v) => v.recited).toList();
    final flagged = recited.where((v) => v.flagged).toList();
    final matched = recited.length - flagged.length;
    final reachedAyah = recited.isEmpty ? 0 : recited.last.ayahNumber;
    final lastAyah = ayahs.isEmpty ? 0 : ayahs.last.number;
    final stoppedEarly = reachedAyah > 0 && reachedAyah < lastAyah;

    // Verdicts indexed by (ayah, word), carrying the rule so each word can be
    // coloured by which mistake it was.
    final markFor = <int, Map<int, WordMark>>{};
    final verdictAt = <int, Map<int, WordVerdict>>{};
    for (final v in verdicts) {
      (verdictAt[v.ayahNumber] ??= {})[v.wordIndex] = v;
      if (!v.recited) continue;
      (markFor[v.ayahNumber] ??= {})[v.wordIndex] =
          v.flagged ? WordMark(WordTone.flagged, rule: v.errorType) : WordMark.recited;
    }
    final counts = <TajweedErrorType, int>{};
    for (final v in flagged) {
      final t = v.errorType;
      if (t != null) counts[t] = (counts[t] ?? 0) + 1;
    }
    const mainRules = [TajweedErrorType.madd, TajweedErrorType.ghunnah, TajweedErrorType.shaddah, TajweedErrorType.makhraj];
    final clean = recited.isEmpty ? const <TajweedErrorType>[] : mainRules.where((r) => (counts[r] ?? 0) == 0).toList();
    final verseScale = context.watch<VerseTextSizeCubit>().state.scale;

    void review(WordVerdict v) => WordReviewSheet.show(
          context,
          verdict: v,
          surahNumber: surahNumber,
          sessionId: result.id,
          audioPcm: result.audioPcm,
        );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, 0),
          sliver: SliverList.list(children: [
            _Summary(matched: matched, recited: recited.length, flagged: flagged.length),
            if (stoppedEarly) ...[
              const SizedBox(height: 6),
              Text('You recited up to ayah $reachedAyah of $lastAyah. The rest is shown in grey and not counted.',
                  style: textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
            if (result.hasanahEarned > 0) HasanahEarnedBanner(amount: result.hasanahEarned),
            const OrnamentDivider(verticalPadding: 20),
            if (flagged.isNotEmpty) ...[
              Text('Needs attention', style: textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in TajweedErrorType.values)
                    if ((counts[r] ?? 0) > 0) RuleChip(rule: r, count: counts[r]),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (clean.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      clean.length == mainRules.length
                          ? 'Nothing was flagged for Madd, Ghunnah, Shaddah or Makhraj.'
                          : 'Nothing was flagged for ${_joinRules(clean)}.',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
          ]),
        ),
        if (flagged.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.lg, AppSpacing.screenPadding, 0),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Words to review',
                subtitle: 'Listen to yourself and a Qari, then try the word again',
              ),
            ),
          ),
        if (flagged.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, 0),
            sliver: SliverList.builder(
              itemCount: flagged.length,
              itemBuilder: (context, i) => _ReviewRow(verdict: flagged[i], onTap: () => review(flagged[i])),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.xl, AppSpacing.screenPadding, AppSpacing.md),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Your recitation',
              subtitle: flagged.isEmpty ? null : 'Hold a marked word to review it',
            ),
          ),
        ),
        // The passage, built lazily: a long surah used to build every ayah at
        // once here.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          sliver: DecoratedSliver(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.lgRadius,
              border: Border.all(color: AppColors.border),
            ),
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              sliver: SliverList.builder(
                itemCount: ayahs.length + 1,
                itemBuilder: (context, i) {
                  if (i == ayahs.length) {
                    final rulesPresent = counts.keys.toSet();
                    if (rulesPresent.isEmpty && !stoppedEarly) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MistakeLegend(rules: rulesPresent, showNotRecited: stoppedEarly),
                    );
                  }
                  final ayah = ayahs[i];
                  final atAyah = verdictAt[ayah.number] ?? const {};
                  return MushafAyah(
                    ayah: ayah,
                    fontSize: 25 * verseScale,
                    marks: markFor[ayah.number] ?? const {},
                    leadingCenteredWords:
                        (ayah.number == 1 && surahNumber != 1 && surahNumber != 9 && ayah.arabicText.split(' ').length > 4)
                            ? 4
                            : 0,
                    onWordLongPress: (index) {
                      final v = atAyah[index];
                      if (v != null && v.recited && v.flagged) review(v);
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  static String _joinRules(List<TajweedErrorType> rules) {
    final names = rules.map((r) => r.label).toList();
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}';
  }
}

class _Summary extends StatelessWidget {
  final int matched;
  final int recited;
  final int flagged;
  const _Summary({required this.matched, required this.recited, required this.flagged});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$matched of $recited words matched the expected recitation. '
          '${flagged == 0 ? 'Nothing to review.' : '$flagged to review.'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: reduce ? matched : 0, end: matched),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text('$value', style: AppTypography.numeric(fontSize: 54)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text('of $recited words matched',
                    style: textTheme.titleLarge?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            flagged == 0
                ? 'Every word you recited matched the expected recitation.'
                : '$flagged word${flagged == 1 ? '' : 's'} worth reviewing. Feedback can be wrong, so listen and judge.',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final WordVerdict verdict;
  final VoidCallback onTap;
  const _ReviewRow({required this.verdict, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rule = verdict.errorType;
    final color = rule == null ? AppColors.errorHighlight : TajweedRuleStyle.color(rule);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${TajweedCopy.headline(rule)}. Ayah ${verdict.ayahNumber}, word ${verdict.wordIndex + 1}.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 76),
                child: Text(
                  verdict.word,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: AppTypography.quran(fontSize: 26, color: color, height: 1.8).copyWith(
                    decoration: rule == null ? null : TajweedRuleStyle.decoration(rule),
                    decorationStyle: rule == null ? null : TajweedRuleStyle.decorationStyle(rule),
                    decorationColor: color,
                    decorationThickness: 2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(TajweedCopy.headline(rule), style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text('Ayah ${verdict.ayahNumber} · word ${verdict.wordIndex + 1}', style: textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// One flagged word, reviewed properly: the word, which rule, the backend's
/// explanation, your own recording beside a Qari's, a retake, a way to
/// disagree, and what the word *is* from the Tajweed reference.
class WordReviewSheet extends StatelessWidget {
  final WordVerdict verdict;
  final int surahNumber;
  final String? sessionId;
  final Uint8List? audioPcm;

  const WordReviewSheet({
    super.key,
    required this.verdict,
    required this.surahNumber,
    this.sessionId,
    this.audioPcm,
  });

  static Future<void> show(
    BuildContext context, {
    required WordVerdict verdict,
    required int surahNumber,
    String? sessionId,
    Uint8List? audioPcm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WordReviewSheet(
        verdict: verdict,
        surahNumber: surahNumber,
        sessionId: sessionId,
        audioPcm: audioPcm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rule = verdict.errorType;
    final color = rule == null ? AppColors.errorHighlight : TajweedRuleStyle.color(rule);
    final textTheme = Theme.of(context).textTheme;
    final pcm = audioPcm;
    final lookup = Services.tajweedReference.word(
      surah: surahNumber,
      ayah: verdict.ayahNumber,
      displayWordIndex: verdict.wordIndex,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: MarkedWord(word: verdict.word, rule: rule, color: color, fontSize: 46)),
              const SizedBox(height: 8),
              FutureBuilder<TajweedWordInfo?>(
                future: lookup,
                builder: (context, snap) {
                  final tr = snap.data?.wordTransliteration ?? '';
                  return Center(
                    child: Text(
                      [if (tr.isNotEmpty) tr, 'Ayah ${verdict.ayahNumber} · word ${verdict.wordIndex + 1}'].join(' · '),
                      style: textTheme.bodySmall?.copyWith(fontStyle: tr.isEmpty ? null : FontStyle.italic),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (rule != null) ...[RuleChip(rule: rule, compact: true), const SizedBox(height: 10)],
              Text(TajweedCopy.headline(rule), style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                (verdict.explanation?.trim().isNotEmpty ?? false) ? verdict.explanation! : TajweedCopy.fallbackBody(rule),
                style: textTheme.bodyLarge?.copyWith(height: 1.55),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (pcm != null)
                    WordPlaybackButton(pcm: pcm, startSec: verdict.startSec, endSec: verdict.endSec),
                  ReferencePlaybackButton(
                    surahNumber: surahNumber,
                    ayahNumber: verdict.ayahNumber,
                    wordIndex: verdict.wordIndex,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Trying again can only lower the mistake count, never raise it,
              // so it is safe to press.
              TryWordAgainButton(
                sessionId: sessionId,
                surahNumber: surahNumber,
                ayahNumber: verdict.ayahNumber,
                wordIndex: verdict.wordIndex,
              ),
              SaidItRightButton(
                sessionId: sessionId,
                ayahNumber: verdict.ayahNumber,
                wordIndex: verdict.wordIndex,
              ),
              FutureBuilder<TajweedWordInfo?>(
                future: lookup,
                builder: (context, snap) {
                  final info = snap.data;
                  if (info == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OrnamentDivider(verticalPadding: 14),
                      Text('About this word', style: textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (info.makhrajEnglish.isNotEmpty)
                        _Fact(
                          label: 'Makhraj',
                          value: info.makhrajLetters.isEmpty
                              ? info.makhrajEnglish
                              : '${info.makhrajEnglish}  ${info.makhrajLetters}',
                        ),
                      if (info.rules.isNotEmpty) _Fact(label: 'Rules in this word', value: info.rules.map(_ruleName).join(', ')),
                      if (info.maddLength > 0) _Fact(label: 'Madd length', value: '${info.maddLength} counts'),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Automatic feedback can be wrong. Listen to both recordings, then decide.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ruleName(String r) => r.isEmpty ? r : '${r[0].toUpperCase()}${r.substring(1)}';
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

// ── Sessions without per-word verdicts ───────────────────────────────────────

/// A result that carries its mistakes but not every word (for instance one
/// read back from history). It lists what was flagged; it never simulates a
/// marked passage it does not have.
class _ErrorListResults extends StatelessWidget {
  final SessionResult result;
  final int surahNumber;
  const _ErrorListResults({required this.result, required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        if (result.wordsRecited > 0)
          _Summary(
            matched: (result.wordsRecited - result.errors.length).clamp(0, result.wordsRecited),
            recited: result.wordsRecited,
            flagged: result.errors.length,
          ),
        const OrnamentDivider(verticalPadding: 20),
        if (result.errors.isEmpty)
          Text('Nothing was flagged in this recitation.', style: Theme.of(context).textTheme.bodyLarge)
        else
          for (final e in result.errors) FlaggedWordRow(error: e, surahNumber: surahNumber),
      ],
    );
  }
}

/// A flagged word from a stored session: the word, the rule's headline, the
/// stored explanation, and a way back to that ayah to practise it.
class FlaggedWordRow extends StatelessWidget {
  final TajweedError error;
  final int surahNumber;
  const FlaggedWordRow({super.key, required this.error, required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    final color = TajweedRuleStyle.color(error.type);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 76),
            child: Text(
              error.word,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: AppTypography.quran(fontSize: 26, color: color, height: 1.8).copyWith(
                decoration: TajweedRuleStyle.decoration(error.type),
                decorationStyle: TajweedRuleStyle.decorationStyle(error.type),
                decorationColor: color,
                decorationThickness: 2,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TajweedCopy.headline(error.type), style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  error.explanation.trim().isEmpty ? TajweedCopy.fallbackBody(error.type) : error.explanation,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  onPressed: () => context.push(RoutePaths.surahDetailsPath(surahNumber,
                      from: error.ayahNumber, to: error.ayahNumber, ayah: error.ayahNumber)),
                  icon: const Icon(Icons.mic_rounded, size: 18),
                  label: Text('Practise ayah ${error.ayahNumber}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
