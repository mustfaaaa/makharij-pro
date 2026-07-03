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
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      maxY: 100,
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                      ],
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
