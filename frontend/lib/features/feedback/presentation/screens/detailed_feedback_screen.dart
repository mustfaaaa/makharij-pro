import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/session_result.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/ui/tajweed_marks.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../recitation/presentation/screens/result_screen.dart';

/// A past recitation, reviewed the same way as a fresh one: what matched, which
/// rules to look at, and each flagged word with a way back to its ayah.
///
/// History keeps the mistakes but not every word or the audio, so there is no
/// marked passage and no "hear yourself" here -- it shows what it has, and
/// counts rather than grades, like the results screen. (It used to colour
/// rules differently from everywhere else and lead with a percentage badge.)
class DetailedFeedbackScreen extends StatefulWidget {
  final String sessionId;
  const DetailedFeedbackScreen({super.key, required this.sessionId});

  @override
  State<DetailedFeedbackScreen> createState() => _DetailedFeedbackScreenState();
}

class _DetailedFeedbackScreenState extends State<DetailedFeedbackScreen> {
  late Future<SessionResult> _sessionFuture = Services.session.getSessionById(widget.sessionId);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recitation review')),
      body: AsyncView<SessionResult>(
        future: _sessionFuture,
        loading: const AppLoadingIndicator(message: 'Loading your recitation'),
        errorMessage: 'This recitation could not be loaded. Check your connection.',
        onRetry: () => setState(() => _sessionFuture = Services.session.getSessionById(widget.sessionId)),
        builder: (context, session) {
          final surah = dummySurahs.where((s) => s.number == session.surahNumber).firstOrNull;
          final from = session.fromAyah;
          // An end in a later surah is not an ayah of this one.
          final to = session.toAyahInOwnSurah;
          final range = from == null ? null : (to == null ? 'From ayah $from' : (to == from ? 'Ayah $from' : 'Ayahs $from–$to'));
          final counts = <TajweedErrorType, int>{};
          for (final e in session.errors) {
            counts[e.type] = (counts[e.type] ?? 0) + 1;
          }
          final matched = (session.wordsRecited - session.errors.length).clamp(0, session.wordsRecited);

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xl),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(surah?.nameEnglish ?? session.surahName, style: textTheme.headlineMedium),
                        Text(
                          [?range, DateFormat.yMMMd().add_jm().format(session.dateTime)].join(' · '),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (surah != null)
                    Text(surah.nameArabic,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.arabicWord(fontSize: 26, color: AppColors.goldInk, weight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (session.wordsRecited > 0)
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$matched', style: AppTypography.numeric(fontSize: 40)),
                    TextSpan(
                      text: '  of ${session.wordsRecited} words matched',
                      style: textTheme.titleMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              if (counts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in TajweedErrorType.values)
                      if ((counts[r] ?? 0) > 0) RuleChip(rule: r, count: counts[r]),
                  ],
                ),
              ],
              const OrnamentDivider(verticalPadding: 20),
              if (session.errors.isEmpty)
                Text('Nothing was flagged in this recitation.', style: textTheme.bodyLarge)
              else ...[
                Text('Words to review', style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                for (final e in session.errors) FlaggedWordRow(error: e, surahNumber: session.surahNumber),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.push(RoutePaths.surahDetailsPath(session.surahNumber, from: from, to: to)),
                icon: const Icon(Icons.mic_rounded, size: 20),
                label: const Text('Recite this passage again'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.push(RoutePaths.practicePlan),
                child: const Text('See your practice plan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
