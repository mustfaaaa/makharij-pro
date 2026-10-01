import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/juz_name.dart';
import '../../../../models/quran_script.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/juz_division.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// The thirty juz, as slivers for the Quran tab's scroll view: where each
/// Tapping one opens the Quran at its first ayah, ready to recite from there.
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
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: SurahCardSkeleton(),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            0,
            AppSpacing.screenPadding,
            AppSpacing.bottomNavClearance,
          ),
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = juzName(juz.number);
    return Semantics(
      button: true,
      label: 'Juz ${juz.number}, ${name.transliteration}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(RoutePaths.juzPath(juz.number)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              RosetteBadge(
                size: 40,
                fill: AppColors.goldWash,
                child: Text(
                  '${juz.number}',
                  style: AppTypography.numeric(
                    fontSize: 12.5,
                    color: AppColors.goldInk,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name.transliteration,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name.arabic,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: AppTypography.quranScript(
                    QuranScript.uthmani,
                    fontSize: 19,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
