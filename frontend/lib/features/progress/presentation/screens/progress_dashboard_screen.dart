import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/progress_point.dart';
import '../../../../models/session_result.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/cards/progress_card.dart';
import '../../../../shared/widgets/cards/recent_session_card.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/sessions_cubit.dart';

class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionsCubit(),
      child: const _ProgressDashboardView(),
    );
  }
}

class _ProgressDashboardView extends StatelessWidget {
  const _ProgressDashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress'), automaticallyImplyLeading: false),
      body: ResponsiveCenter(child: BlocBuilder<SessionsCubit, ListState<SessionResult>>(
        builder: (context, state) {
          if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 5);
          if (state.status == ListStatus.error) {
            return ErrorStateWidget(message: state.errorMessage ?? 'Could not load progress.', onRetry: () => context.read<SessionsCubit>().load());
          }
          final sessions = state.items;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              FutureBuilder<UserProfile>(
                future: Services.user.getCurrentUser(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  return Row(
                    children: [
                      Expanded(child: ProgressCard(label: 'Total Sessions', value: '${user?.totalSessions ?? sessions.length}', icon: Icons.graphic_eq_rounded)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: ProgressCard(label: 'Avg. Accuracy', value: '${(user?.overallAccuracy ?? 0).toStringAsFixed(0)}%', icon: Icons.percent_rounded, trend: '+4%')),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(title: 'Accuracy Trend (14 days)', actionLabel: 'Statistics', onActionTap: () => context.push(RoutePaths.statistics)),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<List<ProgressPoint>>(
                future: Services.progress.getProgressPoints(),
                builder: (context, snapshot) {
                  final points = snapshot.data ?? [];
                  if (points.isEmpty) return const ShimmerBox(height: 200);
                  return Container(
                    height: 200,
                    padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].score)],
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: AppColors.primarySurface),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(title: 'Achievements', actionLabel: 'View all', onActionTap: () => context.push(RoutePaths.achievements)),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text('4 of 6 achievements unlocked', style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Recent Sessions'),
              const SizedBox(height: AppSpacing.sm),
              ...sessions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: RecentSessionCard(session: s, onTap: () => context.push(RoutePaths.detailedFeedbackPath(s.id))),
                ),
              ),
            ],
          );
        },
      )),
    );
  }
}
