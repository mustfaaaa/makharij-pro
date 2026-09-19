import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../models/session_result.dart';
import '../../../../models/tajweed_error.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/tajweed_marks.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/tajweed_rule_style.dart';
import '../bloc/sessions_cubit.dart';

/// How many recitations the chart shows: enough to see a direction, few
/// enough that every bar stays readable on a phone.
const _chartSessions = 12;

/// The detail behind Progress: which rules the flagged words fall under, and
/// how many words matched in each recent recitation. Both come straight from
/// the reciter's own session history.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionsCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Statistics')),
        body: ResponsiveCenter(
          child: BlocBuilder<SessionsCubit, ListState<SessionResult>>(
            builder: (context, state) {
              if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 5);
              if (state.status == ListStatus.error) {
                return ErrorStateWidget(
                  message: state.errorMessage ?? 'Your statistics could not load.',
                  onRetry: () => context.read<SessionsCubit>().load(),
                );
              }
              if (state.items.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.insights_rounded,
                  title: 'Nothing to measure yet',
                  message: 'Statistics appear after your first recitation.',
                );
              }
              // History arrives newest first; the chart reads left to right.
              final recent = state.items.take(_chartSessions).toList().reversed.toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.xl),
                children: [
                  const SectionHeader(
                    title: 'Where the flags fall',
                    subtitle: 'Of the words flagged in your recent recitations, the share under each rule.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _RuleShares(),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Words matched',
                    subtitle: recent.length == 1
                        ? 'Your one recitation so far.'
                        : 'Your last ${recent.length} recitations, oldest to latest.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SessionChart(sessions: recent),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RuleShares extends StatelessWidget {
  const _RuleShares();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<Map<String, double>>(
      future: Services.progress.getErrorTypeBreakdown(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ShimmerBox(height: 120);
        }
        final shares = (snap.data ?? const <String, double>{}).entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (shares.isEmpty) {
          return Text(
            snap.hasError
                ? 'The breakdown could not load. Check your connection and open this page again.'
                : 'After a few recitations, this shows which rules your flagged words fall under.',
            style: textTheme.bodyMedium,
          );
        }
        return Column(children: [for (final e in shares) _ShareRow(label: e.key, percent: e.value)]);
      },
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String label;
  final double percent;
  const _ShareRow({required this.label, required this.percent});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // The breakdown is keyed by the backend's rule label, e.g. "Madd (elongation)".
    final lower = label.toLowerCase();
    final rule = TajweedErrorType.values.where((t) => lower.startsWith(t.id)).firstOrNull;
    final color = rule == null ? AppColors.primary : TajweedRuleStyle.color(rule);
    final name = rule?.label ?? label.split(' (').first;
    return Semantics(
      label: '$name: ${percent.round()} percent of flagged words',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (rule != null) ...[RuleShapeSwatch(rule: rule, width: 22), const SizedBox(width: 10)],
                Expanded(child: Text(name, style: textTheme.titleMedium)),
                Text('${percent.round()}%', style: AppTypography.numeric(fontSize: 16, weight: FontWeight.w700, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.container,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionChart extends StatelessWidget {
  final List<SessionResult> sessions;
  const _SessionChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final last = sessions.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: Semantics(
            label: 'Words matched in your last ${sessions.length} recitations, oldest first: '
                '${sessions.map((e) => '${e.accuracyScore.round()} percent').join(', ')}',
            child: ExcludeSemantics(
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: AppColors.border))),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1, dashArray: const [3, 4]),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.textPrimary,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                        '${rod.toY.round()}%',
                        TextStyle(color: AppColors.textOnInverse, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 50,
                        reservedSize: 38,
                        getTitlesWidget: (value, meta) =>
                            Text('${value.round()}%', style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (sessions.length < 2 || (i != 0 && i != last)) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(i == 0 ? 'Oldest' : 'Latest',
                                style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                            toY: sessions[i].accuracyScore.clamp(0, 100).toDouble(),
                            // The latest recitation is the one to compare against.
                            color: i == last ? AppColors.gold : AppColors.emerald,
                            width: sessions.length > 8 ? 12 : 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sm)),
                            backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: AppColors.container),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Each bar is the share of the words you recited that were not flagged. Words you did not reach are not counted.',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}
