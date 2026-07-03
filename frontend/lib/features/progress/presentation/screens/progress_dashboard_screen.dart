import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../dummy/dummy_progress.dart';
import '../../../../dummy/dummy_sessions.dart';
import '../../../../dummy/dummy_user.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/cards/progress_card.dart';
import '../../../../shared/widgets/cards/recent_session_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Row(
            children: [
              Expanded(child: ProgressCard(label: 'Total Sessions', value: '${dummyUser.totalSessions}', icon: Icons.graphic_eq_rounded)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: ProgressCard(label: 'Avg. Accuracy', value: '${dummyUser.overallAccuracy.toStringAsFixed(0)}%', icon: Icons.percent_rounded, trend: '+4%')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Accuracy Trend (14 days)', actionLabel: 'Statistics', onActionTap: () => context.push(RoutePaths.statistics)),
          const SizedBox(height: AppSpacing.sm),
          Container(
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
                    spots: [
                      for (int i = 0; i < dummyProgressPoints.length; i++) FlSpot(i.toDouble(), dummyProgressPoints[i].score),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.primarySurface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Achievements', actionLabel: 'View all', onActionTap: () => context.push(RoutePaths.achievements)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(child: Text('4 of 6 achievements unlocked', style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Recent Sessions'),
          const SizedBox(height: AppSpacing.sm),
          ...dummySessions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: RecentSessionCard(session: s, onTap: () => context.push(RoutePaths.detailedFeedbackPath(s.id))),
            ),
          ),
        ],
      ),
    );
  }
}
