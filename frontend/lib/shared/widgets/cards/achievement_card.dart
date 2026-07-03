import 'package:flutter/material.dart';

import '../../../models/achievement.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';

class AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const AchievementCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.surface : AppColors.surfaceAlt,
        borderRadius: AppRadii.mdRadius,
        border: Border.all(color: unlocked ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unlocked ? AppColors.accentSurface : AppColors.border.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(achievement.icon, size: 20, color: unlocked ? AppColors.accent : AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            achievement.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: unlocked ? AppColors.textPrimary : AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(achievement.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (!unlocked) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: achievement.progress,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
