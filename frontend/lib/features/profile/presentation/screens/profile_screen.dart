import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/progress_card.dart';
import '../../../../shared/widgets/loading/app_loading_indicator.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/tiles/settings_tile.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _levelLabel(LearningLevel level) {
    switch (level) {
      case LearningLevel.beginner:
        return 'Beginner';
      case LearningLevel.intermediate:
        return 'Intermediate';
      case LearningLevel.advanced:
        return 'Advanced';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          AppIconButton(icon: Icons.settings_outlined, onPressed: () => context.push(RoutePaths.settings)),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ResponsiveCenter(child: FutureBuilder<UserProfile>(
        future: Services.user.getCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) return const AppLoadingIndicator();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(radius: 44, backgroundColor: AppColors.primarySurface, child: Icon(Icons.person, size: 44, color: AppColors.primary)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
                    Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(20)),
                      child: Text(_levelLabel(user.level), style: const TextStyle(color: AppColors.textOnAccent, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: ProgressCard(label: 'Sessions', value: '${user.totalSessions}', icon: Icons.graphic_eq_rounded)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: ProgressCard(label: 'Streak', value: '${user.currentStreak}d', icon: Icons.local_fire_department_rounded)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: ProgressCard(label: 'Accuracy', value: '${user.overallAccuracy.toStringAsFixed(0)}%', icon: Icons.percent_rounded)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Target Surahs', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.targetSurahs.map((s) => Chip(label: Text(s), backgroundColor: AppColors.surfaceAlt)).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SettingsTile(icon: Icons.edit_outlined, title: 'Edit Profile', onTap: () => context.push(RoutePaths.editProfile)),
              SettingsTile(icon: Icons.checklist_rounded, title: 'Practice Plan', onTap: () => context.push(RoutePaths.practicePlan)),
              SettingsTile(icon: Icons.emoji_events_outlined, title: 'Achievements', onTap: () => context.push(RoutePaths.achievements)),
              SettingsTile(icon: Icons.bookmark_outline, title: 'Bookmarks', onTap: () => context.push(RoutePaths.bookmarks)),
              SettingsTile(
                icon: Icons.person_outline,
                title: 'Member since',
                subtitle: DateFormat.yMMMd().format(user.joinedAt),
              ),
            ],
          );
        },
      )),
    );
  }
}
