import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../models/ayah.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// Arabic-Indic digits, so ayah numbers read the way they do in a printed
/// mushaf rather than as Latin numerals.
String arabicNumber(int value) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return value.toString().split('').map((d) => digits[int.parse(d)]).join();
}

/// How a word should be painted in the mushaf text.
enum WordTone {
  /// Not yet recited — the resting state of the whole page.
  pending,

  /// Confirmed as recited by the live analysis while the user speaks.
  recited,

  /// A mistake, from the finished analysis. Never used during recording:
  /// a half-decoded word must not be accused of anything.
  flagged,
}

/// One ayah rendered as flowing, justified mushaf text, closed by a gold
/// ayah-number medallion. Words are individually coloured so recitation
/// progress and mistakes can be shown in place, without breaking the line
/// flow the way per-word boxes would.
class MushafAyah extends StatelessWidget {
  final Ayah ayah;
  final double fontSize;

  /// Tone per word index. Missing entries fall back to [WordTone.pending].
  final Map<int, WordTone> tones;
  final bool showTranslation;
  final VoidCallback? onTap;

  const MushafAyah({
    super.key,
    required this.ayah,
    required this.fontSize,
    this.tones = const {},
    this.showTranslation = false,
    this.onTap,
  });

  Color _colorFor(WordTone tone) {
    switch (tone) {
      case WordTone.pending:
        return AppColors.textMuted;
      case WordTone.recited:
        return AppColors.textPrimary;
      case WordTone.flagged:
        return AppColors.errorHighlight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = ayah.arabicText.split(' ');
    final recognizer = onTap == null ? null : (TapGestureRecognizer()..onTap = onTap);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              for (var i = 0; i < words.length; i++)
                TextSpan(
                  text: i == words.length - 1 ? words[i] : '${words[i]} ',
                  style: AppTypography.arabicVerse(
                    fontSize: fontSize,
                    color: _colorFor(tones[i] ?? WordTone.pending),
                    height: 2.1,
                  ),
                  recognizer: recognizer,
                ),
              const TextSpan(text: ' '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _AyahMedallion(number: ayah.number, size: fontSize * 1.15),
              ),
            ]),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
          ),
          if (showTranslation)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                ayah.translation,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// The gold circle carrying the ayah number, in place of a printed ۝ — drawn
/// rather than typed so it looks the same in every font the app might fall
/// back to.
class _AyahMedallion extends StatelessWidget {
  final int number;
  final double size;
  const _AyahMedallion({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySurface,
        border: Border.all(color: AppColors.primary, width: 1.2),
      ),
      child: Text(
        arabicNumber(number),
        textDirection: TextDirection.rtl,
        style: AppTypography.arabicWord(
          fontSize: size * 0.46,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// The decorative plate above a surah's text: its name and a one-line summary.
///
/// No Basmala here on purpose. The bundled Quran text already opens every
/// surah's ayah 1 with it (At-Tawbah excepted), so printing one would show it
/// twice — and the second copy would carry no recitation highlighting, since
/// only the real ayah text is scored.
class MushafSurahHeader extends StatelessWidget {
  final String nameArabic;
  final String subtitle;
  const MushafSurahHeader({
    super.key,
    required this.nameArabic,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            'سُورَةُ $nameArabic',
            textDirection: TextDirection.rtl,
            style: AppTypography.arabicVerse(
              fontSize: 30,
              color: AppColors.primaryDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
