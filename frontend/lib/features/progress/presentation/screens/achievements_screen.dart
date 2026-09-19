import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/achievement.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../bloc/achievements_cubit.dart';

/// Milestones, each earned from the reciter's own history: earned ones first,
/// then the ones in progress with how far along they are.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AchievementsCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Milestones')),
        body: ResponsiveCenter(
          child: BlocBuilder<AchievementsCubit, ListState<Achievement>>(
            builder: (context, state) {
              if (state.status == ListStatus.loading) {
                return const ShimmerListPlaceholder(itemCount: 5, itemHeight: 84);
              }
              if (state.status == ListStatus.error) {
                return ErrorStateWidget(
                  message: state.errorMessage ?? 'Your milestones could not load.',
                  onRetry: () => context.read<AchievementsCubit>().load(),
                );
              }
              if (state.items.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.emoji_events_outlined,
                  title: 'No milestones yet',
                  message: 'Milestones appear here as you recite.',
                );
              }
              final earned = state.items.where((a) => a.isUnlocked).toList();
              final ahead = state.items.where((a) => !a.isUnlocked).toList()
                ..sort((a, b) => b.progress.compareTo(a.progress));
              final textTheme = Theme.of(context).textTheme;
              return ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.xl),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${earned.length}',
                          style: AppTypography.numeric(fontSize: 40, weight: FontWeight.w700, color: AppColors.goldInk)),
                      const SizedBox(width: 8),
                      Flexible(child: Text('of ${state.items.length} milestones earned', style: textTheme.titleMedium)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Each one is counted from your own recitations.', style: textTheme.bodySmall),
                  if (earned.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _GroupLabel('Earned'),
                    for (final a in earned) _MilestoneRow(achievement: a),
                  ],
                  if (ahead.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _GroupLabel('On the way'),
                    for (final a in ahead) _MilestoneRow(achievement: a),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final Achievement achievement;
  const _MilestoneRow({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final a = achievement;
    final percent = (a.progress.clamp(0.0, 1.0) * 100).round();
    return Semantics(
      label: '${a.title}. ${a.description}. ${a.isUnlocked ? 'Earned' : '$percent percent of the way'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(
          children: [
            RosetteBadge(
              size: 54,
              stroke: a.isUnlocked ? AppColors.gold : AppColors.borderStrong.withValues(alpha: 0.6),
              fill: a.isUnlocked ? AppColors.goldWash : AppColors.surfaceAlt,
              child: Icon(a.icon, size: 22, color: a.isUnlocked ? AppColors.goldInk : AppColors.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(a.description, style: textTheme.bodySmall),
                  if (!a.isUnlocked) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: a.progress.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: AppColors.container,
                              valueColor: AlwaysStoppedAnimation(AppColors.gold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('$percent%', style: AppTypography.numeric(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (a.isUnlocked) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 20, color: AppColors.emerald),
            ],
          ],
        ),
      ),
    );
  }
}
