import 'package:flutter/material.dart';

import '../../../models/surah.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import 'app_card.dart';

class SurahCard extends StatelessWidget {
  final Surah surah;
  final VoidCallback? onTap;

  const SurahCard({super.key, required this.surah, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '${surah.number}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(surah.nameEnglish, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${surah.meaning} · ${surah.ayahCount} Ayahs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(surah.nameArabic, style: AppTypography.arabicWord(fontSize: 20)),
          if (surah.isBookmarked) ...[
            const SizedBox(width: 6),
            Icon(Icons.bookmark, size: 16, color: AppColors.accent),
          ],
        ],
      ),
    );
  }
}
