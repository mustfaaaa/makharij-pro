import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_sessions.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../dummy/dummy_user.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/progress_card.dart';
import '../../../../shared/widgets/cards/recent_session_card.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/navigation/app_drawer.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final continueSurah = dummySurahs[1];
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('MakharijPro AI'),
        actions: [
          AppIconButton(icon: Icons.search, onPressed: () => context.push(RoutePaths.search)),
          const SizedBox(width: 8),
          AppIconButton(icon: Icons.notifications_none_rounded, onPressed: () => context.push(RoutePaths.notifications)),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text('Assalamu Alaikum, ${dummyUser.name.split(' ').first}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Ready to continue your Tajweed practice?', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ProgressCard(
                  label: 'Overall Accuracy',
                  value: '${dummyUser.overallAccuracy.toStringAsFixed(0)}%',
                  icon: Icons.percent_rounded,
                  trend: '+4%',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ProgressCard(
                  label: 'Day Streak',
                  value: '${dummyUser.currentStreak} days',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Continue Recitation', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(continueSurah.nameEnglish, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: Icons.play_arrow_rounded,
                  background: Colors.white,
                  iconColor: AppColors.primary,
                  size: 48,
                  onPressed: () => context.push(RoutePaths.recitationPath(continueSurah.number)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: 'Recent Sessions', actionLabel: 'See all', onActionTap: () => context.push(RoutePaths.statistics)),
          const SizedBox(height: AppSpacing.sm),
          ...dummySessions.take(3).map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: RecentSessionCard(
                    session: s,
                    onTap: () => context.push(RoutePaths.detailedFeedbackPath(s.id)),
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          SectionHeader(title: 'Suggested Surahs', actionLabel: 'View all', onActionTap: () => context.go(RoutePaths.quran)),
          const SizedBox(height: AppSpacing.sm),
          ...dummySurahs.take(3).map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SurahCard(surah: s, onTap: () => context.push(RoutePaths.surahDetailsPath(s.number))),
                ),
              ),
        ],
      ),
    );
  }
}
