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
import '../../../../shared/widgets/hasanah/hasanah_earned_banner.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/recitation_cubit.dart';
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
      // Guards against a direct deep-link to this route without going
      // through the recitation -> processing flow first.
      return const Scaffold(body: Center(child: Text('No result available for this session.')));
    }

    if (!_hasanahCredited) {
      _hasanahCredited = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<HasanahCubit>().addHasanah(result.hasanahEarned);
      });
    }

    final color = scoreColor(result.accuracyScore);
    final errorWordSet = {for (final e in result.errors) e.word};

    return Scaffold(
      appBar: AppBar(title: const Text('Result'), automaticallyImplyLeading: false),
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
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: result.accuracyScore),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Text('${value.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color));
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Tajweed Accuracy Score', style: Theme.of(context).textTheme.bodyMedium),
                        if (result.totalWords > 0) ...[
                          const SizedBox(height: 2),
                          // Accuracy alone is misleading: three words recited
                          // perfectly is 100%. Coverage is what makes the
                          // number readable.
                          Text(
                            'over ${result.wordsRecited} of ${result.totalWords} words',
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
  const _RealWordResults({required this.ayahs, required this.verdicts, this.audioPcm});

  @override
  Widget build(BuildContext context) {
    final recited = verdicts.where((v) => v.recited).toList();
    final flagged = recited.where((v) => v.flagged).toList();
    final reachedAyah = recited.isEmpty ? 0 : recited.last.ayahNumber;
    final lastAyah = ayahs.isEmpty ? 0 : ayahs.last.number;
    final stoppedEarly = reachedAyah > 0 && reachedAyah < lastAyah;

    // Verdicts indexed by (ayah, word) so each rendered word can find its own.
    final toneFor = <int, Map<int, WordTone>>{};
    for (final v in verdicts) {
      if (!v.recited) continue;
      (toneFor[v.ayahNumber] ??= {})[v.wordIndex] =
          v.flagged ? WordTone.flagged : WordTone.recited;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          flagged.isEmpty
              ? 'No mistakes found — excellent recitation!'
              : '${flagged.length} word${flagged.length == 1 ? '' : 's'} need attention',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          stoppedEarly
              ? 'You recited up to ayah $reachedAyah of $lastAyah. '
                  'Everything after that stays greyed out — not counted as a mistake.'
              : 'Every word you recited was checked against the expected pronunciation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final ayah in ayahs)
                MushafAyah(
                  ayah: ayah,
                  fontSize: 22,
                  tones: toneFor[ayah.number] ?? const {},
                ),
            ],
          ),
        ),
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('What went wrong', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final v in flagged) _MistakeCard(verdict: v, audioPcm: audioPcm),
        ],
      ],
    );
  }
}

/// The written explanation for one flagged word: which rule, what to fix, and
/// the chance to hear how you actually said it.
class _MistakeCard extends StatelessWidget {
  final WordVerdict verdict;
  final Uint8List? audioPcm;
  const _MistakeCard({required this.verdict, this.audioPcm});

  @override
  Widget build(BuildContext context) {
    final label = verdict.errorType?.label ?? 'Pronunciation';
    final pcm = audioPcm;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorHighlight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(color: AppColors.errorHighlight, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Ayah ${verdict.ayahNumber} · word ${verdict.wordIndex + 1}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text(verdict.word, style: AppTypography.arabicWord(fontSize: 20, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            verdict.explanation ?? 'This word did not match the expected pronunciation.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (pcm != null)
            Align(
              alignment: Alignment.centerLeft,
              child: WordPlaybackButton(
                pcm: pcm,
                startSec: verdict.startSec,
                endSec: verdict.endSec,
              ),
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
                errorCount == 0 ? 'No errors detected — excellent recitation!' : '$errorCount words need attention',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
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
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
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
                      ? BoxDecoration(color: AppColors.errorHighlightBg, borderRadius: BorderRadius.circular(6))
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
