import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_ayahs.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

class RecitationScreen extends StatelessWidget {
  final int surahNumber;
  const RecitationScreen({super.key, required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    final surah = dummySurahs.firstWhere((s) => s.number == surahNumber, orElse: () => dummySurahs.first);
    return Scaffold(
      appBar: AppBar(title: Text(surah.nameEnglish)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Text(
                  'Recite clearly and at a natural pace. MakharijPro will listen and flag any Tajweed mistakes.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ...dummyFatihahAyahs.map(
                  (ayah) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(ayah.arabicText, style: AppTypography.arabicVerse(), textAlign: TextAlign.right),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIconButton(
                  icon: Icons.mic_rounded,
                  size: 68,
                  background: AppColors.primary,
                  iconColor: Colors.white,
                  onPressed: () => context.push(RoutePaths.listeningPath(surahNumber)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
