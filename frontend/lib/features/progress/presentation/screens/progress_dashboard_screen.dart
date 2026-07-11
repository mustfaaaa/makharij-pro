import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../core/utils/current_user_display.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../dummy/dummy_user.dart';
import '../../../../routes/route_names.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

// ── Tajweed Mastery data (matches the mockup) ─────────────────────────────────
class _RuleMastery {
  final String name;
  final int pct;
  final Color dot;
  const _RuleMastery(this.name, this.pct, this.dot);
}

const _mastery = [
  _RuleMastery('Makhraj', 82, Color(0xFFC9A227)),
  _RuleMastery('Ghunnah', 68, Color(0xFFB08F4F)),
  _RuleMastery('Shaddah', 90, Color(0xFF8B6914)),
  _RuleMastery('Madd', 74, Color(0xFFCE6A1B)),
  _RuleMastery('Qalqalah', 79, Color(0xFFD4B87A)),
];

// ── 14-day accuracy trend (gently rising, like the mockup) ────────────────────
const _trend = [71.0, 72.5, 72.0, 74.0, 75.5, 76.0, 77.5, 77.0, 78.5, 80.0, 81.0, 82.5, 83.0, 86.0];

// ── 10-week practice heatmap (0–4 intensity per day) ─────────────────────────
const _heatmap = [
  [1, 2, 0, 1, 0, 3, 4],
  [0, 3, 3, 2, 4, 3, 2],
  [2, 1, 2, 0, 1, 2, 3],
  [0, 0, 2, 1, 3, 2, 4],
  [1, 2, 0, 3, 2, 4, 3],
  [2, 0, 1, 2, 3, 2, 4],
  [0, 1, 3, 2, 1, 3, 2],
  [1, 3, 2, 4, 2, 3, 4],
  [2, 1, 0, 2, 3, 4, 3],
  [1, 2, 3, 1, 2, 3, 4],
];

class _Badge {
  final String label;
  final IconData icon;
  final bool unlocked;
  const _Badge(this.label, this.icon, this.unlocked);
}

const _badges = [
  _Badge('First Recitation', Icons.mic_rounded, true),
  _Badge('7-Day Streak', Icons.water_drop_rounded, true),
  _Badge('Makhraj Master', Icons.blur_circular_rounded, true),
  _Badge('100 Ayat', Icons.menu_book_rounded, true),
  _Badge('Perfect Score', Icons.lock_rounded, false),
];

/// Progress tab rebuilt to the provided mockup: performance dashboard hero
/// on the provided Quran photo, stat cards, Tajweed Mastery bars, the
/// 14-day Accuracy Trend chart, the 10-week Practice Activity heatmap and
/// the Achievements badge row.
class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 12, AppSpacing.screenPadding, bottomPad),
          children: [
            // ── Header row ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(currentUserInitial(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentUserName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Your Performance',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.pillRadius,
                    boxShadow: [
                      BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 5),
                      Text('${dummyUser.currentStreak} days',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Performance dashboard hero ───────────────────────────────
            const _PerformanceHero(),
            const SizedBox(height: AppSpacing.md),
            // ── Stat cards ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                    child: _StatCard(
                        icon: Icons.menu_book_rounded,
                        value: '${dummyUser.totalSessions}',
                        label: 'Sessions')),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatCard(
                        icon: Icons.water_drop_rounded,
                        value: '${dummyUser.currentStreak}d',
                        label: 'Streak')),
                const SizedBox(width: 10),
                Expanded(
                  child: BlocBuilder<HasanahCubit, int>(
                    builder: (context, hasanah) => _StatCard(
                        icon: Icons.auto_awesome,
                        value: formatWithCommas(hasanah),
                        label: 'Hasanah'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Tajweed Mastery ──────────────────────────────────────────
            _SectionCard(
              icon: Icons.nightlight_round,
              title: 'Tajweed Mastery',
              subtitle: 'Your accuracy by rule',
              child: Column(
                children: [
                  for (final rule in _mastery)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: rule.dot, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 76,
                            child: Text(rule.name,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(child: _MasteryBar(pct: rule.pct)),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 40,
                            child: Text('${rule.pct}%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Accuracy Trend ───────────────────────────────────────────
            _SectionCard(
              icon: Icons.trending_up_rounded,
              title: 'Accuracy Trend',
              subtitle: 'Last 14 days',
              trailing: GestureDetector(
                onTap: () => context.push(RoutePaths.statistics),
                child: Text('Statistics',
                    style: TextStyle(
                        color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              child: const Padding(
                padding: EdgeInsets.only(top: 16),
                child: SizedBox(height: 140, child: _TrendChart()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Practice Activity heatmap ────────────────────────────────
            _SectionCard(
              icon: Icons.grid_view_rounded,
              title: 'Practice Activity',
              subtitle: 'Last 10 weeks',
              child: const Padding(
                padding: EdgeInsets.only(top: 16),
                child: _ActivityHeatmap(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Achievements ─────────────────────────────────────────────
            _SectionCard(
              icon: Icons.emoji_events_rounded,
              title: 'Achievements',
              subtitle: '4 of 6 unlocked',
              trailing: GestureDetector(
                onTap: () => context.push(RoutePaths.achievements),
                child: Text('View all',
                    style: TextStyle(
                        color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final badge in _badges)
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: badge.unlocked
                                    ? LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [AppColors.primaryLight, AppColors.primaryDark])
                                    : null,
                                color: badge.unlocked ? null : AppColors.surfaceAlt,
                              ),
                              child: Icon(badge.icon,
                                  color: badge.unlocked ? Colors.white : AppColors.textMuted, size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(badge.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: badge.unlocked
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dark performance hero: the photo fills a fixed-height card so the
// full glowing mushaf is visible, with content centered over it. ─────────────
class _PerformanceHero extends StatelessWidget {
  const _PerformanceHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.lgRadius,
      child: Stack(
        children: [
          // Fixed height so the image fully fills the card.
          const SizedBox(height: 220, width: double.infinity),
          Positioned.fill(
            child: Image.asset('assets/images/quran_dark.jpg',
                fit: BoxFit.cover, alignment: const Alignment(0, 0.35)),
          ),
          // Scrim: lightest over the book so it stays prominent, deeper at
          // the edges for readable gold text.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.48),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PERFORMANCE DASHBOARD',
                      style: TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 2.2)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Gold accuracy ring.
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: CircularProgressIndicator(
                                value: dummyUser.overallAccuracy / 100,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withValues(alpha: 0.18),
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${dummyUser.overallAccuracy.round()}%',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                        height: 1.0)),
                                Text('accuracy',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Overall Accuracy',
                                style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                            const SizedBox(height: 4),
                            Text("Great progress \u2014 you're improving steadily.",
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 13.5,
                                    height: 1.35)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Colors.white, borderRadius: AppRadii.pillRadius),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspace_premium_rounded,
                                          size: 14, color: AppColors.primaryDark),
                                      const SizedBox(width: 4),
                                      const Text('Intermediate',
                                          style: TextStyle(
                                              color: Color(0xFF2D2A26),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1F6E4E),
                                      borderRadius: AppRadii.pillRadius),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.trending_up_rounded, size: 14, color: Colors.white),
                                      SizedBox(width: 3),
                                      Text('+4%',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small stat card ───────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.smRadius),
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, fontSize: 22)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Reusable white section card with icon + title + subtitle ─────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgRadius,
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
                child: Icon(icon, size: 20, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          child,
        ],
      ),
    );
  }
}

// ── Gradient mastery bar ──────────────────────────────────────────────────────
class _MasteryBar extends StatelessWidget {
  final int pct;
  const _MasteryBar({required this.pct});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
                color: AppColors.creamDark, borderRadius: BorderRadius.circular(6)),
          ),
          Container(
            height: 10,
            width: constraints.maxWidth * pct / 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primaryLight, const Color(0xFF8B6914)]),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 14-day accuracy line chart ────────────────────────────────────────────────
class _TrendChart extends StatelessWidget {
  const _TrendChart();

  @override
  Widget build(BuildContext context) {
    const labels = {0: 'Mon', 4: 'Fri', 8: 'Tue', 13: 'Sun'};
    return LineChart(
      LineChartData(
        minY: 65,
        maxY: 92,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final label = labels[value.toInt()];
                if (label == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < _trend.length; i++) FlSpot(i.toDouble(), _trend[i])],
            isCurved: true,
            curveSmoothness: 0.32,
            barWidth: 2.6,
            color: AppColors.accent,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, data) => spot.x == _trend.length - 1,
              getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                radius: 4.5,
                color: AppColors.accent,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.accent.withValues(alpha: 0.35),
                  AppColors.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 10-week practice heatmap grid ─────────────────────────────────────────────
class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap();

  Color _shade(int level) {
    switch (level) {
      case 0:
        return AppColors.creamDark;
      case 1:
        return AppColors.accentLight.withValues(alpha: 0.55);
      case 2:
        return AppColors.accentLight;
      case 3:
        return AppColors.primary;
      default:
        return const Color(0xFF8B6914);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 7 rows (days) × 10 columns (weeks), like the mockup.
        for (int day = 0; day < 7; day++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (int week = 0; week < _heatmap.length; week++) ...[
                  if (week > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _shade(_heatmap[week][day]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            const SizedBox(width: 6),
            for (int i = 0; i < 5; i++) ...[
              Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                    color: _shade(i), borderRadius: BorderRadius.circular(3.5)),
              ),
            ],
            const SizedBox(width: 2),
            Text('More', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ],
        ),
      ],
    );
  }
}
