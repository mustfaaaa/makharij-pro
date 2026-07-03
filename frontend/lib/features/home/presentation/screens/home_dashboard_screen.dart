import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/session_result.dart';
import '../../../../models/surah.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/progress_card.dart';
import '../../../../shared/widgets/cards/recent_session_card.dart';
import '../../../../shared/widgets/cards/surah_card.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/navigation/app_drawer.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../progress/presentation/bloc/sessions_cubit.dart';
import '../../../quran/presentation/bloc/surah_list_cubit.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SurahListCubit()),
        BlocProvider(create: (_) => SessionsCubit()),
      ],
      child: const _HomeDashboardView(),
    );
  }
}

class _HomeDashboardView extends StatelessWidget {
  const _HomeDashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('MakharijPro AI'),
        actions: [
          AppIconButton(icon: Icons.search, tooltip: 'Search', onPressed: () => context.push(RoutePaths.search)),
          const SizedBox(width: 8),
          AppIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onPressed: () => context.push(RoutePaths.notifications)),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          FutureBuilder<UserProfile>(
            future: Services.user.getCurrentUser(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) return const ShimmerBox(height: 56);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assalamu Alaikum, ${user.name.split(' ').first}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Ready to continue your Tajweed practice?', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: ProgressCard(
                          label: 'Overall Accuracy',
                          value: '${user.overallAccuracy.toStringAsFixed(0)}%',
                          icon: Icons.percent_rounded,
                          trend: '+4%',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ProgressCard(
                          label: 'Day Streak',
                          value: '${user.currentStreak} days',
                          icon: Icons.local_fire_department_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          BlocBuilder<SurahListCubit, ListState<Surah>>(
            builder: (context, state) {
              if (state.items.isEmpty) return const SizedBox.shrink();
              final continueSurah = state.items[state.items.length > 1 ? 1 : 0];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
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
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: 'Recent Sessions', actionLabel: 'See all', onActionTap: () => context.push(RoutePaths.statistics)),
          const SizedBox(height: AppSpacing.sm),
          BlocBuilder<SessionsCubit, ListState<SessionResult>>(
            builder: (context, state) {
              if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 3, itemHeight: 64);
              final sessions = state.items.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < sessions.length; i++)
                    StaggeredFadeSlide(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: RecentSessionCard(
                          session: sessions[i],
                          onTap: () => context.push(RoutePaths.detailedFeedbackPath(sessions[i].id)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SectionHeader(title: 'Suggested Surahs', actionLabel: 'View all', onActionTap: () => context.go(RoutePaths.quran)),
          const SizedBox(height: AppSpacing.sm),
          BlocBuilder<SurahListCubit, ListState<Surah>>(
            builder: (context, state) {
              if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 3, itemHeight: 64);
              final surahs = state.items.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < surahs.length; i++)
                    StaggeredFadeSlide(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SurahCard(surah: surahs[i], onTap: () => context.push(RoutePaths.surahDetailsPath(surahs[i].number))),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
