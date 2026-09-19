import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../models/qari.dart';
import '../../../../services/rattil_request_parser.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// One ayah's Arabic and translation, sized by the reader's verse-size setting
/// like every other place the app shows Quran text.
class RattilAyahText extends StatelessWidget {
  final String arabic;
  final String translation;

  const RattilAyahText({super.key, required this.arabic, required this.translation});

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<VerseTextSizeCubit>().state.scale;
    return ConstrainedBox(
      // Al-Baqarah 282 runs to a page; it scrolls inside the card rather than
      // pushing the controls off the screen.
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: AppTypography.quran(fontSize: 24 * scale, height: 2.0),
            ),
            const SizedBox(height: 6),
            Text(
              translation,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reciters as calligraphic name plates: the name in Arabic, the name
/// people say it by, and how much of the Quran they have -- the thing that
/// decides whether picking them will work. Reciters are shown by name, never
/// by photograph.
class QariPicker extends StatelessWidget {
  final List<Qari> qaris;
  final Qari? selected;
  final int totalSurahs;
  final ValueChanged<Qari> onPick;

  const QariPicker({
    super.key,
    required this.qaris,
    required this.selected,
    required this.totalSurahs,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 4);
    // Three reciters share the width, so every one is in view at once; a
    // longer list scrolls sideways instead.
    if (qaris.length <= 3) {
      return SizedBox(
        height: 96,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < qaris.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _plate(context, qaris[i])),
              ],
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: qaris.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 112, maxWidth: 160),
          child: _plate(context, qaris[i]),
        ),
      ),
    );
  }

  Widget _plate(BuildContext context, Qari q) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isSelected = q.qariId == selected?.qariId;
    final coverage = q.availableSurahs.length >= totalSurahs ? 'Whole Quran' : '${q.availableSurahs.length} surahs';
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Reciter ${q.nameEnglish}, $coverage',
      excludeSemantics: true,
      child: Tooltip(
        message: q.nameEnglish,
        child: Pressable(
          onTap: () => onPick(q),
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface : AppColors.surface,
              borderRadius: AppRadii.lgRadius,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    q.nameArabic,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    style: AppTypography.arabicWord(
                      fontSize: 17,
                      color: AppColors.goldInk,
                      weight: FontWeight.w700,
                    ).copyWith(height: 1.3),
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        RattilRequestParser.shortName(q),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: isSelected ? AppColors.onPrimarySurface : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle_rounded, size: 15, color: AppColors.primaryDark),
                    ],
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(coverage, maxLines: 1, style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
