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
import '../../../../shared/widgets/cards/recent_session_card.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text('Progress', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveCenter(
        child: BlocBuilder<SessionsCubit, ListState<SessionResult>>(
          builder: (context, state) {
            if (state.status == ListStatus.loading) {
              return const ShimmerListPlaceholder(itemCount: 5);
            }
            if (state.status == ListStatus.error) {
              return ErrorStateWidget(
                message: state.errorMessage ?? 'Could not load progress.',
                onRetry: () => context.read<SessionsCubit>().load(),
              );
            }
            final sessions = state.items;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
                AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // Quick stats
                FutureBuilder<UserProfile>(
                  future: Services.user.getCurrentUser(),
                  builder: (context, snap) {
                    final user = snap.data;
                    return Row(children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.menu_book_rounded,
                          iconColor: AppColors.success,
                          value: '${user?.totalSessions ?? sessions.length}',
                          label: 'Total Sessions',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppColors.primary,
                          value: '${user?.currentStreak ?? 0}',
                          label: 'Day Streak',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.trending_up_rounded,
                          iconColor: AppColors.primary,
                          value: '${(user?.overallAccuracy ?? 0).toStringAsFixed(0)}%',
                          label: 'Avg Score',
                          trend: '+4%',
                        ),
                      ),
                    ]);
                  },
                ),
                const SizedBox(height: 24),

                // Accuracy breakdown
                Text('Tajweed Breakdown',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(children: [
                    _AccuracyRow(label: 'Makhraj', percent: 0.82, color: AppColors.primary),
                    SizedBox(height: 14),
                    _AccuracyRow(label: 'Ghunnah', percent: 0.70, color: Color(0xFF5B8DEF)),
                    SizedBox(height: 14),
                    _AccuracyRow(label: 'Madd', percent: 0.65, color: AppColors.success),
                    SizedBox(height: 14),
                    _AccuracyRow(label: 'Qalqalah', percent: 0.88, color: Color(0xFFE07B39)),
                  ]),
                ),
                const SizedBox(height: 24),

                // Accuracy trend chart
                SectionHeader(
                    title: 'Accuracy Trend',
                    actionLabel: 'Statistics',
                    onActionTap: () => context.push(RoutePaths.statistics)),
                const SizedBox(height: AppSpacing.sm),
                FutureBuilder<List<ProgressPoint>>(
                  future: Services.progress.getProgressPoints(),
                  builder: (context, snapshot) {
                    final points = snapshot.data ?? [];
                    if (points.isEmpty) return const ShimmerBox(height: 200);
                    return Container(
                      height: 200,
                      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                      decoration: AppTheme.cardDecoration(),
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
                              belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Achievements summary
                SectionHeader(
                    title: 'Achievements',
                    actionLabel: 'View all',
                    onActionTap: () => context.push(RoutePaths.achievements)),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
                  ),
                  child: Row(children: [
                    Icon(Icons.emoji_events_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('4 of 6 achievements unlocked', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Recent sessions
                const SectionHeader(title: 'Recent Sessions'),
                const SizedBox(height: AppSpacing.sm),
                ...sessions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: RecentSessionCard(
                      session: s,
                      onTap: () => context.push(RoutePaths.detailedFeedbackPath(s.id)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value, label;
  final String? trend;
  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label, this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: iconColor, size: 20),
            if (trend != null)
              Row(children: [
                Icon(Icons.trending_up_rounded, size: 12, color: AppColors.success),
                const SizedBox(width: 2),
                Text(trend!, style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
              ]),
          ],
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  const _AccuracyRow({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 72,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text('${(percent * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}
