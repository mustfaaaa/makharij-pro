import 'package:flutter/material.dart';

import '../../../models/surah.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// Surah list card — gold number badge, Arabic name, practiced % badge or ayat count.
class SurahCard extends StatelessWidget {
  final Surah surah;
  final VoidCallback? onTap;

  const SurahCard({super.key, required this.surah, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // Gold number circle
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(
                '${surah.number}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const SizedBox(width: 14),

            // Name + meaning
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surah.nameArabic, textDirection: TextDirection.rtl, style: AppTypography.arabicWord(fontSize: 19)),
                  const SizedBox(height: 3),
                  Text(
                    '${surah.nameEnglish} / ${surah.meaning}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: practiced badge OR ayat count
            if (surah.lastScore != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'Practiced ${surah.lastScore!.round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              )
            else
              Text(
                '${surah.ayahCount} Ayat',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),

            if (surah.isBookmarked) ...[
              const SizedBox(width: 6),
              Icon(Icons.bookmark_rounded, size: 16, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
