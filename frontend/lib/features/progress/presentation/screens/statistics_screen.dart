import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/session_result.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/cards/statistics_card.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/sessions_cubit.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionsCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Statistics')),
        body: ResponsiveCenter(child: BlocBuilder<SessionsCubit, ListState<SessionResult>>(
          builder: (context, state) {
            if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 5);
            if (state.status == ListStatus.error) {
              return ErrorStateWidget(message: state.errorMessage ?? 'Could not load statistics.', onRetry: () => context.read<SessionsCubit>().load());
            }
            final sessions = state.items;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Text('Error Breakdown by Rule', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                FutureBuilder<Map<String, double>>(
                  future: Services.progress.getErrorTypeBreakdown(),
                  builder: (context, snapshot) {
                    final breakdown = snapshot.data ?? {};
                    return Column(
                      children: breakdown.entries
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: StatisticsCard(label: e.key, percentage: e.value),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Session Accuracy (Last ${sessions.length})', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
                  // Every axis used to be hidden and touch disabled, so not a
                  // single number could be read off this chart -- it was a
                  // picture of bars. Y labels give it a scale, X labels say
                  // which session, and a tooltip gives the exact value.
                  child: Semantics(
                    label: 'Accuracy for the last ${sessions.length} sessions, '
                        'oldest first: ${sessions.map((e) => '${e.accuracyScore.round()} percent').join(', ')}',
                    child: ExcludeSemantics(
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 25,
                            getDrawingHorizontalLine: (v) =>
                                FlLine(color: AppColors.divider, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          maxY: 100,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => AppColors.textPrimary,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                                '${rod.toY.round()}%',
                                TextStyle(
                                    color: AppColors.textOnInverse,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 25,
                                reservedSize: 34,
                                getTitlesWidget: (value, meta) => Text(
                                  '${value.round()}%',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  // Label only the ends on a crowded axis.
                                  if (i != 0 && i != sessions.length - 1) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      i == 0 ? 'oldest' : 'latest',
                                      style: TextStyle(
                                          color: AppColors.textMuted, fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            for (int i = 0; i < sessions.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: sessions[i].accuracyScore,
                                    color: AppColors.primary,
                                    width: 22,
                                    borderRadius: BorderRadius.circular(AppRadii.sm),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        )),
      ),
    );
  }
}
