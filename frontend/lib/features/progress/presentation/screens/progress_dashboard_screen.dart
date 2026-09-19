import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../dummy/dummy_surahs.dart';
import '../../../../models/achievement.dart';
import '../../../../models/progress_point.dart';
import '../../../../models/progress_summary.dart';
import '../../../../models/session_result.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/ui/ornaments.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../widgets/performance_hero.dart';

/// Drops the parenthetical from a backend rule label ("Madd (elongation)" ->
/// "Madd") so it fits the bar row.
String _shortRuleLabel(String label) => label.split(' (').first;

/// Progress: the reciter's own history, read as a learning journey rather
/// than a business dashboard -- a streak, the surahs they have recited mapped
/// across the whole Quran, how their recitations have gone over time, which
/// rules to practise, milestones, and the recitations themselves.
///
/// Every figure comes from `/progress`, `/sessions`, `/achievements` or the
/// hasanah total in Firestore. Nothing is estimated or dressed up: a new
/// reciter sees one invitation, not a wall of zeros.
class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  late Future<ProgressSummary> _summary;
  late Future<List<ProgressPoint>> _points;
  late Future<List<Achievement>> _achievements;
  late Future<List<SessionResult>> _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summary = Services.progress.getSummary();
    _points = Services.progress.getProgressPoints().catchError((_) => <ProgressPoint>[]);
    _achievements = Services.achievement.getAchievements().catchError((_) => <Achievement>[]);
    _sessions = Services.session.getSessions().catchError((_) => <SessionResult>[]);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _summary.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: FutureBuilder<ProgressSummary>(
            future: _summary,
            builder: (context, snap) {
              final header = [
                Text('Progress', style: textTheme.displayMedium),
                const SizedBox(height: 2),
                Text('Measured from your own recitations', style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
              ];
              final List<Widget> body;
              if (snap.hasError) {
                body = [
                  const SizedBox(height: AppSpacing.xl),
                  ErrorStateWidget(
                    title: 'Your progress could not load',
                    message: 'Check your connection and try again.',
                    onRetry: () => setState(_load),
                  ),
                ];
              } else if (snap.connectionState != ConnectionState.done) {
                body = const [
                  ShimmerBox(height: 110, borderRadius: BorderRadius.all(Radius.circular(20))),
                  SizedBox(height: AppSpacing.md),
                  ShimmerBox(height: 220, borderRadius: BorderRadius.all(Radius.circular(20))),
                  SizedBox(height: AppSpacing.md),
                  ShimmerBox(height: 140, borderRadius: BorderRadius.all(Radius.circular(20))),
                ];
              } else if (snap.data!.totalSessions == 0) {
                body = [
                  const SizedBox(height: AppSpacing.lg),
                  EmptyStateWidget(
                    icon: Icons.auto_graph_rounded,
                    title: 'Your progress starts with a recitation',
                    message:
                        'Recite any passage and this page fills in: your streak, the surahs you have recited, and the rules worth practising.',
                    actionLabel: 'Choose a surah',
                    onAction: () => context.go(RoutePaths.quran),
                  ),
                ];
              } else {
                final s = snap.data!;
                body = [
                  _StreakSection(summary: s),
                  const SizedBox(height: AppSpacing.lg),
                  PerformanceHero(overallAccuracy: s.overallAccuracy, totalSessions: s.totalSessions),
                  const SizedBox(height: AppSpacing.xl),
                  _QuranMap(sessions: _sessions),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Over time', subtitle: 'Words matched on each day you recited'),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 190,
                    child: FutureBuilder<List<ProgressPoint>>(
                      future: _points,
                      builder: (context, p) => _TrendChart(points: p.data ?? const []),
                    ),
                  ),
                  if (s.ruleMastery.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'By rule',
                      subtitle: 'Recited words not flagged for each rule, last 20 recitations',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final e in (s.ruleMastery.entries.toList()..sort((a, b) => a.value.compareTo(b.value))))
                      _RuleBar(label: _shortRuleLabel(e.key), value: e.value),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _Milestones(achievements: _achievements),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Activity', subtitle: 'Recitations per day, last 10 weeks'),
                  const SizedBox(height: AppSpacing.md),
                  _ActivityHeatmap(heatmap: s.activityHeatmap),
                  const SizedBox(height: AppSpacing.xl),
                  _RecentRecitations(sessions: _sessions),
                ];
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.bottomNavClearance),
                children: [...header, ...body],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Streak ───────────────────────────────────────────────────────────────────

class _StreakSection extends StatelessWidget {
  final ProgressSummary summary;
  const _StreakSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // The heatmap is the last 70 days in order, oldest first; its last 14
    // entries are the last two weeks ending today.
    final days = summary.activityHeatmap.expand((w) => w).toList();
    final last14 = days.length >= 14 ? days.sublist(days.length - 14) : days;
    final streak = summary.currentStreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              label: '$streak day streak',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$streak', style: AppTypography.numeric(fontSize: 52)),
                  const SizedBox(width: 8),
                  Text(streak == 1 ? 'day in a row' : 'days in a row',
                      style: textTheme.titleMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Spacer(),
            BlocBuilder<HasanahCubit, int>(
              builder: (context, h) => h <= 0
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatWithCommas(h), style: AppTypography.numeric(fontSize: 20, color: AppColors.goldInk)),
                        Text('hasanah', style: textTheme.bodySmall),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (last14.isNotEmpty)
          Semantics(
            label: 'Recited on ${last14.where((d) => d > 0).length} of the last ${last14.length} days',
            excludeSemantics: true,
            child: Row(
              children: [
                for (var i = 0; i < last14.length; i++) ...[
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: RosetteBadge(
                        size: 22,
                        stroke: last14[i] > 0 ? AppColors.gold : AppColors.border,
                        fill: last14[i] > 0 ? AppColors.goldWash : Colors.transparent,
                      ),
                    ),
                  ),
                  if (i < last14.length - 1) const SizedBox(width: 3),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('Two weeks ago', style: textTheme.labelSmall),
            const Spacer(),
            Text('Today', style: textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

// ── Quran map ────────────────────────────────────────────────────────────────

/// All 114 surahs in order, the ones recited filled in. The honest version of
/// "surah completion": it records that a surah has been recited, not that it
/// has been mastered.
class _QuranMap extends StatelessWidget {
  final Future<List<SessionResult>> sessions;
  const _QuranMap({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SessionResult>>(
      future: sessions,
      builder: (context, snap) {
        final recited = {for (final s in snap.data ?? const <SessionResult>[]) s.surahNumber};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Your Quran map',
              subtitle: '${recited.length} of 114 surahs recited · tap one to open it',
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(builder: (context, constraints) {
              const perRow = 19;
              const gap = 4.0;
              final cell = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
              return Semantics(
                label: '${recited.length} of 114 surahs recited',
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var n = 1; n <= 114; n++)
                      Tooltip(
                        message: dummySurahs.where((s) => s.number == n).firstOrNull?.nameEnglish ?? 'Surah $n',
                        child: InkWell(
                          onTap: () => context.push(RoutePaths.surahDetailsPath(n)),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: cell,
                            height: cell,
                            decoration: BoxDecoration(
                              color: recited.contains(n) ? AppColors.emerald : AppColors.container,
                              borderRadius: BorderRadius.circular(cell * 0.28),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Al-Fatihah', style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text('An-Nas', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Trend ────────────────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<ProgressPoint> points;
  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (points.length < 2) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: AppRadii.lgRadius, border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('Recite on two different days to see how your recitations change over time.',
            textAlign: TextAlign.center, style: textTheme.bodyMedium),
      );
    }

    final labelIndexes = <int>{0, points.length - 1};
    final labelStyle = textTheme.labelSmall;
    return Semantics(
      label: 'Words matched per day, from ${points.first.score.round()} percent to ${points.last.score.round()} percent',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 50,
                getTitlesWidget: (value, meta) => Text('${value.round()}%', style: labelStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (!labelIndexes.contains(i) || i < 0 || i >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(DateFormat.MMMd().format(points[i].date), style: labelStyle),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${DateFormat.MMMd().format(points[s.x.toInt()].date)}\n${s.y.round()}% matched',
                        TextStyle(color: AppColors.textOnInverse, fontWeight: FontWeight.w600, fontFamily: 'Figtree'),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].score)],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              barWidth: 2.4,
              color: AppColors.primary,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                  radius: index == points.length - 1 ? 4.5 : 2.5,
                  color: index == points.length - 1 ? AppColors.gold : AppColors.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary.withValues(alpha: 0.16), AppColors.primary.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rules ────────────────────────────────────────────────────────────────────

class _RuleBar extends StatelessWidget {
  final String label;
  final double value;
  const _RuleBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$label: ${value.round()} percent of recited words not flagged',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: textTheme.titleSmall)),
                Text('${value.round()}%', style: AppTypography.numeric(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduce ? value / 100 : 0, end: value / 100),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: AppColors.emerald,
                  backgroundColor: AppColors.container,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Milestones ───────────────────────────────────────────────────────────────

class _Milestones extends StatelessWidget {
  final Future<List<Achievement>> achievements;
  const _Milestones({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<List<Achievement>>(
      future: achievements,
      builder: (context, snap) {
        final items = [...(snap.data ?? const <Achievement>[])]
          ..sort((a, b) => (b.isUnlocked ? 1 : 0).compareTo(a.isUnlocked ? 1 : 0));
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Milestones',
              subtitle: '${items.where((a) => a.isUnlocked).length} of ${items.length} reached',
              actionLabel: 'All',
              onActionTap: () => context.push(RoutePaths.achievements),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final a = items[i];
                  return Semantics(
                    label: '${a.title}. ${a.description}. ${a.isUnlocked ? 'Reached' : '${(a.progress * 100).round()} percent of the way'}',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 96,
                      child: Column(
                        children: [
                          RosetteBadge(
                            size: 64,
                            stroke: a.isUnlocked ? AppColors.gold : AppColors.border,
                            fill: a.isUnlocked ? AppColors.goldWash : Colors.transparent,
                            child: Icon(a.icon, size: 24, color: a.isUnlocked ? AppColors.goldInk : AppColors.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Text(a.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelMedium?.copyWith(
                                color: a.isUnlocked ? AppColors.textPrimary : AppColors.textSecondary,
                              )),
                          const SizedBox(height: 4),
                          if (!a.isUnlocked)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: a.progress.clamp(0.0, 1.0),
                                minHeight: 3,
                                color: AppColors.gold,
                                backgroundColor: AppColors.container,
                              ),
                            )
                          else
                            Text('Reached', style: textTheme.labelSmall?.copyWith(color: AppColors.goldInk)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Activity ─────────────────────────────────────────────────────────────────

class _ActivityHeatmap extends StatelessWidget {
  final List<List<int>> heatmap;
  const _ActivityHeatmap({required this.heatmap});

  Color _level(int v) => switch (v) {
        0 => AppColors.container,
        1 => Color.lerp(AppColors.container, AppColors.emerald, 0.35)!,
        2 => Color.lerp(AppColors.container, AppColors.emerald, 0.6)!,
        3 => Color.lerp(AppColors.container, AppColors.emerald, 0.8)!,
        _ => AppColors.emerald,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weeks = heatmap.isEmpty ? List.generate(10, (_) => List.filled(7, 0)) : heatmap;
    final days = weeks.expand((w) => w).where((v) => v > 0).length;
    return Semantics(
      label: 'Recited on $days of the last ${weeks.length * 7} days',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              for (var w = 0; w < weeks.length; w++) ...[
                Expanded(
                  child: Column(
                    children: [
                      for (var d = 0; d < weeks[w].length; d++) ...[
                        AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _level(weeks[w][d]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        if (d < weeks[w].length - 1) const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
                if (w < weeks.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('10 weeks ago', style: textTheme.labelSmall),
              const Spacer(),
              Text('Less', style: textTheme.labelSmall),
              const SizedBox(width: 6),
              for (final v in [0, 1, 2, 4]) ...[
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _level(v), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 3),
              ],
              const SizedBox(width: 3),
              Text('More', style: textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Recent recitations ───────────────────────────────────────────────────────

class _RecentRecitations extends StatelessWidget {
  final Future<List<SessionResult>> sessions;
  const _RecentRecitations({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<List<SessionResult>>(
      future: sessions,
      builder: (context, snap) {
        final items = (snap.data ?? const <SessionResult>[]).take(6).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'Recent recitations', actionLabel: 'Statistics', onActionTap: () => context.push(RoutePaths.statistics)),
            const SizedBox(height: AppSpacing.sm),
            for (final s in items)
              InkWell(
                onTap: () => context.push(RoutePaths.detailedFeedbackPath(s.id)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                dummySurahs.where((x) => x.number == s.surahNumber).firstOrNull?.nameEnglish ?? s.surahName,
                                if (s.fromAyah != null)
                                  (s.toAyah == null || s.toAyah == s.fromAyah) ? 'ayah ${s.fromAyah}' : 'ayahs ${s.fromAyah}–${s.toAyah}',
                              ].join(' · '),
                              style: textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (s.wordsRecited > 0)
                                  '${(s.wordsRecited - s.errors.length).clamp(0, s.wordsRecited)} of ${s.wordsRecited} words matched',
                                relativeTime(s.dateTime),
                              ].join(' · '),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
