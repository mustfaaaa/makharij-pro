import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../features/quran/presentation/widgets/mushaf_ayah.dart';
import '../../../../models/ayah.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../models/word_verdict.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/outlined_app_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/hasanah/hasanah_earned_banner.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';
import '../bloc/recitation_cubit.dart';
import '../widgets/mistake_breakdown.dart';
import '../widgets/reference_playback_button.dart';
import '../widgets/said_it_right_button.dart';
import '../widgets/mistake_legend.dart';
import '../widgets/word_playback_button.dart';

class ResultScreen extends StatefulWidget {
  final int surahNumber;
  const ResultScreen({super.key, required this.surahNumber});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _hasanahCredited = false;

  @override
  Widget build(BuildContext context) {
    final recitationState = context.watch<RecitationCubit>().state;
    final result = recitationState.result;
    final ayahs = recitationState.selectedAyahs;
    if (result == null) {
      // Guards against a direct deep-link to this route without going through
      // the recitation -> processing flow first. This used to be a bare
      // centred sentence with no app bar and no back button -- a dead end the
      // user could only escape by killing the app.
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: EmptyStateWidget(
          icon: Icons.mic_none_rounded,
          title: 'No result to show',
          message:
              'This page shows the feedback for a recitation you just finished. '
              'Pick a surah and recite to get one.',
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

    final color = scoreColor(result.accuracyScore);
    final errorWordSet = {for (final e in result.errors) e.word};
    final toCheck = result.errors.length;
    final matched = (result.wordsRecited - toCheck).clamp(0, result.wordsRecited);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        automaticallyImplyLeading: false,
        actions: [
          // The flow arrives here via pushReplacement, so there is no back
          // stack to pop -- an explicit way home is the only exit besides the
          // buttons at the bottom.
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              context.read<RecitationCubit>().reset();
              context.go(RoutePaths.home);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1), border: Border.all(color: color, width: 4)),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: FittedBox(
                            // A count of what matched, not a percentage graded
                            // on the reciter. "78% Tajweed Accuracy" reads as a
                            // verdict on them, and the detector wrongly flags
                            // roughly two correct recitations in five -- a
                            // count states what was measured and claims nothing
                            // more (see ml/eval/README.md).
                            child: TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: matched),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: '$value'),
                                    TextSpan(
                                      text: ' / ${result.wordsRecited}',
                                      style: Theme.of(context).textTheme.titleMedium
                                          ?.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ]),
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('words matched the expected recitation',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium),
                        if (result.totalWords > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            toCheck == 0
                                ? 'of ${result.totalWords} in this passage'
                                : '$toCheck worth listening back to',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HasanahEarnedBanner(amount: result.hasanahEarned),
                  const SizedBox(height: AppSpacing.xl),
                  if (result.wordVerdicts != null && result.wordVerdicts!.isNotEmpty)
                    _RealWordResults(
                      ayahs: ayahs,
                      verdicts: result.wordVerdicts!,
                      surahNumber: result.surahNumber,
                      sessionId: result.id,
                      audioPcm: result.audioPcm,
                    )
                  else
                    _PreviewWordHighlight(ayahs: ayahs, errorWordSet: errorWordSet, errorCount: result.errors.length),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'View Detailed Feedback',
                    icon: Icons.analytics_outlined,
                    onPressed: () => context.push(RoutePaths.detailedFeedbackPath(result.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Practice Again',
                          onPressed: () {
                            // Back to the same mushaf reading page recitation
                            // started from -- there is only one place to recite.
                            context.read<RecitationCubit>().beginSession(widget.surahNumber);
                            context.pushReplacement(RoutePaths.surahDetailsPath(widget.surahNumber));
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Done',
                          onPressed: () {
                            context.read<RecitationCubit>().reset();
                            context.go(RoutePaths.home);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real, evidence-based per-word results: the phoneme model's own recognized
/// output for each word, diffed against the ayah's canonical phoneme sequence.
/// No "Preview" chip here -- unlike [_PreviewWordHighlight], every flagged word
/// traces back to an actual measurement.
///
/// The surah is rendered from the app's own text, in the same mushaf layout as
/// the reading page, with verdicts painted onto it. Rendering the response's
/// word list instead meant any ayah the backend trimmed from that list simply
/// vanished from the results -- and a long surah is trimmed by design.
class _RealWordResults extends StatelessWidget {
  final List<Ayah> ayahs;
  final List<WordVerdict> verdicts;
  final Uint8List? audioPcm;
  final int surahNumber;
  final String? sessionId;
  const _RealWordResults({
    required this.ayahs,
    required this.verdicts,
    required this.surahNumber,
    this.sessionId,
    this.audioPcm,
  });

  @override
  Widget build(BuildContext context) {
    final recited = verdicts.where((v) => v.recited).toList();
    final flagged = recited.where((v) => v.flagged).toList();
    final reachedAyah = recited.isEmpty ? 0 : recited.last.ayahNumber;
    final lastAyah = ayahs.isEmpty ? 0 : ayahs.last.number;
    final stoppedEarly = reachedAyah > 0 && reachedAyah < lastAyah;

    // Verdicts indexed by (ayah, word) so each rendered word can find its own,
    // carrying the rule so the page can colour it by which mistake it was.
    final markFor = <int, Map<int, WordMark>>{};
    for (final v in verdicts) {
      if (!v.recited) continue;
      (markFor[v.ayahNumber] ??= {})[v.wordIndex] = v.flagged
          ? WordMark(WordTone.flagged, rule: v.errorType)
          : WordMark.recited;
    }
    final counts = MistakeBreakdown.tally(flagged.map((v) => v.errorType));
    final rulesPresent = counts.keys.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (flagged.isNotEmpty) ...[
          // Which rules, and how many -- the pattern worth practising, which
          // scattered coloured words alone don't tell you.
          MistakeBreakdown(counts: counts),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          flagged.isEmpty
              ? 'Everything matched — excellent recitation!'
              : '${flagged.length} place${flagged.length == 1 ? '' : 's'} worth checking',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          stoppedEarly
              ? 'You recited up to ayah $reachedAyah of $lastAyah. '
                  'Everything after that stays greyed out — not counted as a mistake.'
              : 'Each word was compared with the expected recitation. Where they differ, '
                  'listen back and judge for yourself.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final ayah in ayahs)
                MushafAyah(
                  ayah: ayah,
                  fontSize: 22,
                  marks: markFor[ayah.number] ?? const {},
                ),
              if (rulesPresent.isNotEmpty || stoppedEarly) ...[
                const SizedBox(height: AppSpacing.xs),
                MistakeLegend(rules: rulesPresent, showNotRecited: stoppedEarly),
              ],
            ],
          ),
        ),
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Worth checking', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final v in flagged)
            _MistakeCard(
              verdict: v,
              surahNumber: surahNumber,
              sessionId: sessionId,
              audioPcm: audioPcm,
            ),
        ],
      ],
    );
  }
}

/// The written explanation for one flagged word: which rule, what to fix, and
/// the chance to hear how you actually said it.
class _MistakeCard extends StatelessWidget {
  final WordVerdict verdict;
  final int surahNumber;
  final String? sessionId;
  final Uint8List? audioPcm;
  const _MistakeCard({
    required this.verdict,
    required this.surahNumber,
    this.sessionId,
    this.audioPcm,
  });

  @override
  Widget build(BuildContext context) {
    final rule = verdict.errorType;
    final label = rule?.label ?? 'Pronunciation';
    // Same colour as the word in the verse above, so the eye joins the two.
    final color = rule == null ? AppColors.errorHighlight : TajweedRuleStyle.color(rule);
    final pcm = audioPcm;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap, not Row: the rule label, the "Ayah N · word M" locator and
          // the Arabic word together overflow a 375px screen -- and overflow
          // sooner at a large system text size. Wrapping reflows instead of
          // painting the yellow-and-black overflow stripes.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Text(label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Text('Ayah ${verdict.ayahNumber} · word ${verdict.wordIndex + 1}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              Text(verdict.word, style: AppTypography.arabicWord(fontSize: 20, color: color)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            verdict.explanation ?? 'This word sounded different from what was expected.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          // The reciter's own word beside a Qari saying the same one. Two
          // recordings to compare beats a sentence telling them who was right.
          Wrap(
            spacing: 4,
            children: [
              if (pcm != null)
                WordPlaybackButton(
                  pcm: pcm,
                  startSec: verdict.startSec,
                  endSec: verdict.endSec,
                ),
              ReferencePlaybackButton(
                surahNumber: surahNumber,
                ayahNumber: verdict.ayahNumber,
                wordIndex: verdict.wordIndex,
              ),
              // The last word belongs to the reciter. Two correct recitations
              // in five are flagged wrongly, so a verdict they can't overrule
              // would be the screen claiming a certainty it doesn't have.
              SaidItRightButton(
                sessionId: sessionId,
                ayahNumber: verdict.ayahNumber,
                wordIndex: verdict.wordIndex,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fallback shown when real word-level results aren't available for this
/// surah/ayah combination yet -- a labeled simulation, not presented as live
/// AI output. See session_service.dart's _generatePreviewErrors.
class _PreviewWordHighlight extends StatelessWidget {
  final List<Ayah> ayahs;
  final Set<String> errorWordSet;
  final int errorCount;
  const _PreviewWordHighlight({required this.ayahs, required this.errorWordSet, required this.errorCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                errorCount == 0 ? 'Everything matched — excellent recitation!' : '$errorCount places worth checking',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadii.lg)),
              child: Text('Preview', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Word-level highlighting is a preview of a future feature — not yet live AI output.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
          child: Wrap(
            alignment: WrapAlignment.end,
            textDirection: TextDirection.rtl,
            spacing: 6,
            runSpacing: 10,
            children: ayahs.expand((ayah) {
              return ayah.arabicText.split(' ').map((word) {
                final isError = errorWordSet.contains(word);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: isError
                      ? BoxDecoration(color: AppColors.errorHighlightBg, borderRadius: BorderRadius.circular(AppRadii.sm))
                      : null,
                  child: Text(
                    word,
                    style: AppTypography.arabicWord(fontSize: 22, color: isError ? AppColors.errorHighlight : AppColors.textPrimary),
                  ),
                );
              });
            }).toList(),
          ),
        ),
      ],
    );
  }
}
