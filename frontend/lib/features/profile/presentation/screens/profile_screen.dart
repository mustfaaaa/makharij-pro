import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../dummy/dummy_progress.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../../shared/widgets/cards/progress_card.dart';
import '../../../../shared/widgets/cards/statistics_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/tajweed_color_guide.dart';
import '../../../../shared/widgets/tiles/settings_tile.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String levelLabel(LearningLevel level) {
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
      body: AsyncView<UserProfile>(
        future: Services.user.getCurrentUser(),
        errorMessage: 'Could not load your profile.',
        builder: (context, user) => _ProfileBody(user: user),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserProfile user;
  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 240,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(RoutePaths.settings),
            ),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: _ProfileHeader(user: user),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat cards
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

                // Tajweed mastery as clean progress bars
                const SectionHeader(title: 'Tajweed Mastery'),
                const SizedBox(height: AppSpacing.sm),
                ...dummyTajweedMastery.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: StatisticsCard(label: e.key, percentage: e.value, color: tajweedRuleColors[e.key]),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Target surahs
                const SectionHeader(title: 'Target Surahs'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: user.targetSurahs
                      .map((s) => Chip(
                            label: Text(s),
                            backgroundColor: AppColors.primarySurface,
                            side: BorderSide.none,
                            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Account menu
                const SectionHeader(title: 'Account'),
                SettingsTile(icon: Icons.edit_outlined, title: 'Edit Profile', onTap: () => context.push(RoutePaths.editProfile)),
                SettingsTile(icon: Icons.checklist_rounded, title: 'Practice Plan', onTap: () => context.push(RoutePaths.practicePlan)),
                SettingsTile(icon: Icons.emoji_events_outlined, title: 'Achievements', onTap: () => context.push(RoutePaths.achievements)),
                SettingsTile(icon: Icons.bookmark_outline, title: 'Bookmarks', onTap: () => context.push(RoutePaths.bookmarks)),
                SettingsTile(icon: Icons.settings_outlined, title: 'Settings', onTap: () => context.push(RoutePaths.settings)),
                SettingsTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Member since',
                  subtitle: DateFormat.yMMMd().format(user.joinedAt),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentLight, width: 2),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 10),
              Text(user.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 2),
              Text(user.email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      ProfileScreen.levelLabel(user.level),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
