import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../models/qari.dart';
import '../../../../services/rattil_request_parser.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_shadows.dart';
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
              style: AppTypography.arabicVerse(fontSize: 22 * scale, height: 2.0),
            ),
            const SizedBox(height: 6),
            Text(
              translation,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// One pill per reciter, with how much of the Quran they have beneath the
/// name -- the thing that decides whether picking them will work.
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
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 4),
        itemCount: qaris.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final q = qaris[i];
          final isSelected = q.qariId == selected?.qariId;
          final coverage = q.availableSurahs.length >= totalSurahs
              ? 'Whole Quran'
              : '${q.availableSurahs.length} surahs';
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
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: AppRadii.pillRadius,
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    boxShadow: isSelected ? AppShadows.md : AppShadows.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        RattilRequestParser.shortName(q),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        coverage,
                        style: textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? AppColors.textOnPrimary.withValues(alpha: 0.85)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
