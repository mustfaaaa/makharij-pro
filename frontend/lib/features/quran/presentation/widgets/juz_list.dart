import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/quran_script.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/juz_division.dart';
import '../../../../services/quran_script_repository.dart';
import '../../../../services/quran_text_repository.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// The thirty juz, as slivers for the Quran tab's scroll view: where each
/// begins and ends, and its opening words. Tapping one opens the Quran at its
/// first ayah, ready to recite from there.
class JuzSliverList extends StatefulWidget {
  const JuzSliverList({super.key});

  @override
  State<JuzSliverList> createState() => _JuzSliverListState();
}

class _JuzSliverListState extends State<JuzSliverList> {
  late Future<JuzDivision> _division = JuzDivision.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JuzDivision>(
      future: _division,
      builder: (context, snap) {
        if (snap.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorStateWidget(
              title: 'The juz could not be listed',
              message: 'The Quran text bundled with the app did not load.',
              onRetry: () => setState(() => _division = JuzDivision.load()),
            ),
          );
        }
        final division = snap.data;
        if (division == null) {
          return SliverList.builder(
            itemCount: 8,
            itemBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: SurahCardSkeleton(),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.bottomNavClearance),
          sliver: SliverList.builder(
            itemCount: division.all.length,
            itemBuilder: (context, i) => _JuzRow(juz: division.all[i]),
          ),
        );
      },
    );
  }
}

class _JuzRow extends StatelessWidget {
  final JuzBoundary juz;
  const _JuzRow({required this.juz});

  static String _surahName(int number) =>
      dummySurahs.where((s) => s.number == number).firstOrNull?.nameEnglish ?? 'Surah $number';

  /// "Al-Baqarah 142 – 252", or "Al-Baqarah 253 – Aal-E-Imran 92" when the
  /// juz runs into another surah.
  String get _span {
    final from = '${_surahName(juz.start.surah)} ${juz.start.ayah}';
    final to = juz.end.surah == juz.start.surah
        ? '${juz.end.ayah}'
        : '${_surahName(juz.end.surah)} ${juz.end.ayah}';
    return '$from – $to';
  }

  /// The juz's first words, as the Uthmani text writes them -- how a juz is
  /// traditionally known. Taken from the text itself, never typed: the hizb
  /// ornament, silent waqf signs and a surah's opening Basmala are passed over.
  /// The Uthmani text writes the ornament both as a word of its own and again
  /// at the head of the next one, so it is stripped, not just skipped.
  String get _opening {
    final words = QuranScriptRepository.instance.ayah(juz.start.surah, juz.start.ayah, QuranScript.uthmani)?.words;
    if (words == null) return '';
    final basmala = juz.start.ayah == 1 && juz.start.surah != 1 && juz.start.surah != 9 ? 4 : 0;
    return words
        .skip(basmala)
        .map((w) => w.replaceAll(_ornament, '').trim())
        .where((w) => w.isNotEmpty && !w.runes.every(QuranTextRepository.isMark))
        .take(2)
        .join(' ');
  }

  /// The start-of-hizb sign (۞) and the sajda sign (۩).
  static final _ornament = RegExp('[۞۩]');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final span = _span;
    return Semantics(
      button: true,
      label: 'Juz ${juz.number}, $span',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(RoutePaths.juzPath(juz.number)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            children: [
              RosetteBadge(
                size: 40,
                fill: AppColors.goldWash,
                child: Text('${juz.number}', style: AppTypography.numeric(fontSize: 12.5, color: AppColors.goldInk)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Juz ${juz.number}', style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      span,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _opening,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: AppTypography.quranScript(QuranScript.uthmani, fontSize: 19, color: AppColors.textPrimary, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
