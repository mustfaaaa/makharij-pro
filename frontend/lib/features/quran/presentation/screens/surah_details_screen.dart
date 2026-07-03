import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_ayahs.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/surah.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;
  const SurahDetailsScreen({super.key, required this.surahNumber});

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> {
  late bool _bookmarked;

  @override
  void initState() {
    super.initState();
    _bookmarked = surah.isBookmarked;
  }

  Surah get surah => dummySurahs.firstWhere((s) => s.number == widget.surahNumber, orElse: () => dummySurahs.first);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(surah.nameEnglish),
        actions: [
          AppIconButton(
            icon: _bookmarked ? Icons.bookmark : Icons.bookmark_outline,
            iconColor: _bookmarked ? AppColors.accent : AppColors.textPrimary,
            onPressed: () => setState(() => _bookmarked = !_bookmarked),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    children: [
                      Text(surah.nameArabic, style: AppTypography.arabicVerse(fontSize: 32, color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Text('${surah.meaning} · ${surah.ayahCount} Ayahs · ${surah.revelationPlace}', style: Theme.of(context).textTheme.bodySmall),
                      if (surah.lastScore != null) ...[
                        const SizedBox(height: 8),
                        Text('Last score: ${surah.lastScore!.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Preview', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ...dummyFatihahAyahs.map(
                  (ayah) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ayah.arabicText, style: AppTypography.arabicVerse(), textAlign: TextAlign.right),
                        const SizedBox(height: 4),
                        Text(ayah.translation, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.left),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: PrimaryButton(
              label: 'Start Recitation',
              icon: Icons.mic_rounded,
              onPressed: () => context.push(RoutePaths.recitationPath(surah.number)),
            ),
          ),
        ],
      ),
    );
  }
}
