import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../models/progress_point.dart';
import '../../../../models/session_result.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/cards/recent_session_card.dart';
import '../../../../shared/widgets/cards/section_card.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../bloc/sessions_cubit.dart';

// Per-rule mastery, warm gold-family palette (stays on-theme, still legible
// as distinct rows). Values are the dummy mastery scores.
class _Rule {
  final String label;
  final double value;
  final Color color;
  const _Rule(this.label, this.value, this.color);
}

const _rules = [
  _Rule('Makhraj', 82, Color(0xFFC2A366)),
  _Rule('Ghunnah', 68, Color(0xFFCE8A1B)),
  _Rule('Shaddah', 90, Color(0xFFB08F4F)),
  _Rule('Madd', 74, Color(0xFFC9772E)),
  _Rule('Qalqalah', 79, Color(0xFFC9A227)),
];

class _Achievement {
  final IconData icon;
  final String label;
  final bool unlocked;
  const _Achievement(this.icon, this.label, this.unlocked);
}

const _achievements = [
  _Achievement(Icons.mic_rounded, 'First Recitation', true),
  _Achievement(Icons.local_fire_department_rounded, '7-Day Streak', true),
  _Achievement(Icons.center_focus_strong_rounded, 'Makhraj Master', true),
  _Achievement(Icons.menu_book_rounded, '100 Ayat', true),
  _Achievement(Icons.star_rounded, 'Perfect Score', false),
  _Achievement(Icons.calendar_month_rounded, '30-Day Streak', false),
];

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
        automaticallyImplyLeading: false,
        title: Text(
          'Progress',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 22),
        ),
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
                AppSpacing.sm,
                AppSpacing.screenPadding,
                AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                FutureBuilder<UserProfile>(
                  future: Services.user.getCurrentUser(),
                  builder: (context, snap) {
                    final user = snap.data;
                    return Column(
                      children: [
                        StaggeredFadeSlide(index: 0, child: _HeroAccuracyCard(user: user)),
                        const SizedBox(height: 16),
                        StaggeredFadeSlide(index: 1, child: _StatRow(user: user, sessionCount: sessions.length)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                StaggeredFadeSlide(index: 2, child: const _TajweedMasteryCard()),
                const SizedBox(height: 16),

                StaggeredFadeSlide(
                  index: 3,
                  child: _AccuracyTrendCard(onStats: () => context.push(RoutePaths.statistics)),
                ),
                const SizedBox(height: 16),

                StaggeredFadeSlide(index: 4, child: const _ActivityHeatmapCard()),
                const SizedBox(height: 16),

                StaggeredFadeSlide(
                  index: 5,
                  child: _AchievementsCard(onViewAll: () => context.push(RoutePaths.achievements)),
                ),
                const SizedBox(height: 24),

                StaggeredFadeSlide(index: 6, child: const SectionHeader(title: 'Recent Sessions')),
                const SizedBox(height: AppSpacing.sm),
                for (int i = 0; i < sessions.length; i++)
                  StaggeredFadeSlide(
                    index: 7 + i,
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
      ),
    );
  }
}

// ── Hero: animated accuracy ring + summary ───────────────────────────────────

class _HeroAccuracyCard extends StatelessWidget {
  final UserProfile? user;
  const _HeroAccuracyCard({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const ShimmerBox(height: 150);
    final level = switch (user!.level) {
      LearningLevel.beginner => 'Beginner',
      LearningLevel.intermediate => 'Intermediate',
      LearningLevel.advanced => 'Advanced',
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          _AccuracyRing(value: user!.overallAccuracy),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Accuracy', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Great progress — you\'re improving steadily.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.primaryDark),
                          const SizedBox(width: 4),
                          Text(
                            level,
                            style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.trending_up_rounded, size: 16, color: AppColors.success),
                    const SizedBox(width: 2),
                    Text('+4%', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracyRing extends StatefulWidget {
  final double value; // 0..100
  const _AccuracyRing({required this.value});

  @override
  State<_AccuracyRing> createState() => _AccuracyRingState();
}

class _AccuracyRingState extends State<_AccuracyRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final shown = widget.value * t;
        return SizedBox(
          width: 116,
          height: 116,
          child: CustomPaint(
            painter: _RingPainter(fraction: (widget.value / 100) * t, track: AppColors.divider),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${shown.round()}%',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                  Text('accuracy', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color track;
  _RingPainter({required this.fraction, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final shader = const SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [Color(0xFFE6CC94), Color(0xFFC2A366), Color(0xFFB08F4F)],
    ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.fraction != fraction;
}

// ── Stat row (count-up mini cards) ───────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final UserProfile? user;
  final int sessionCount;
  const _StatRow({required this.user, required this.sessionCount});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const ShimmerBox(height: 90);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book_rounded,
            value: user!.totalSessions.toDouble(),
            label: 'Sessions',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            value: user!.currentStreak.toDouble(),
            suffix: 'd',
            label: 'Streak',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.auto_awesome_rounded,
            value: user!.hasanahCount.toDouble(),
            label: 'Hasanah',
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  final String? suffix;
  final bool compact;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.suffix,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              final text = compact ? formatWithCommas(v.round()) : '${v.round()}${suffix ?? ''}';
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Tajweed mastery (animated bars) ──────────────────────────────────────────

class _TajweedMasteryCard extends StatelessWidget {
  const _TajweedMasteryCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.donut_large_rounded,
      title: 'Tajweed Mastery',
      subtitle: 'Your accuracy by rule',
      child: Column(
        children: [
          for (int i = 0; i < _rules.length; i++) ...[
            _MasteryBar(rule: _rules[i], delayMs: i * 90),
            if (i != _rules.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _MasteryBar extends StatelessWidget {
  final _Rule rule;
  final int delayMs;
  const _MasteryBar({required this.rule, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: rule.value / 100),
      duration: Duration(milliseconds: 1000 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: rule.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 74,
              child: Text(
                rule.label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(height: 9, color: AppColors.divider),
                    FractionallySizedBox(
                      widthFactor: t.clamp(0.0, 1.0),
                      child: Container(
                        height: 9,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [rule.color.withValues(alpha: 0.7), rule.color],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                '${(t * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: rule.color),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Accuracy trend (animated line chart) ─────────────────────────────────────

class _AccuracyTrendCard extends StatelessWidget {
  final VoidCallback onStats;
  const _AccuracyTrendCard({required this.onStats});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.show_chart_rounded,
      title: 'Accuracy Trend',
      subtitle: 'Last 14 days',
      trailing: GestureDetector(
        onTap: onStats,
        child: Text(
          'Statistics',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: FutureBuilder<List<ProgressPoint>>(
        future: Services.progress.getProgressPoints(),
        builder: (context, snapshot) {
          final points = snapshot.data ?? [];
          if (points.isEmpty) return const ShimmerBox(height: 170);
          final scores = points.map((p) => p.score).toList();
          final best = scores.reduce(math.max);
          final avg = scores.reduce((a, b) => a + b) / scores.length;
          return Column(
            children: [
              SizedBox(
                height: 150,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: 100,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primaryDark,
                          getTooltipItems: (spots) => spots
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.round()}%',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].score * t),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.32,
                          color: AppColors.primary,
                          barWidth: 3.5,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) => spot.x == points.length - 1,
                            getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                              radius: 4.5,
                              color: AppColors.primaryDark,
                              strokeWidth: 2,
                              strokeColor: AppColors.surface,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.22),
                                AppColors.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _TrendChip(label: 'Best', value: '${best.round()}%'),
                  const SizedBox(width: 10),
                  _TrendChip(label: 'Average', value: '${avg.round()}%'),
                  const SizedBox(width: 10),
                  _TrendChip(label: 'Latest', value: '${scores.last.round()}%'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String label, value;
  const _TrendChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Practice activity heatmap (GitHub-style) ─────────────────────────────────

class _ActivityHeatmapCard extends StatelessWidget {
  const _ActivityHeatmapCard();

  // Deterministic mock intensities (0..4) for the last 10 weeks × 7 days.
  static const _weeks = 10;
  int _intensity(int week, int day) => (week * 3 + day * 5 + (week ~/ 2)) % 5;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.grid_view_rounded,
      title: 'Practice Activity',
      subtitle: 'Last 10 weeks',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 4.0;
          final cell = ((constraints.maxWidth - gap * (_weeks - 1)) / _weeks).clamp(10.0, 22.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int w = 0; w < _weeks; w++)
                    Column(
                      children: [
                        for (int d = 0; d < 7; d++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: gap),
                            child: _Cell(intensity: _intensity(w, d), size: cell),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Less', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  for (int i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: _Cell(intensity: i, size: 11),
                    ),
                  const SizedBox(width: 3),
                  Text('More', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int intensity;
  final double size;
  const _Cell({required this.intensity, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = intensity == 0
        ? AppColors.surfaceAlt
        : AppColors.primary.withValues(alpha: 0.18 + intensity * 0.2);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );
  }
}

// ── Achievements showcase ────────────────────────────────────────────────────

class _AchievementsCard extends StatelessWidget {
  final VoidCallback onViewAll;
  const _AchievementsCard({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.unlocked).length;
    return SectionCard(
      icon: Icons.emoji_events_rounded,
      title: 'Achievements',
      subtitle: '$unlocked of ${_achievements.length} unlocked',
      trailing: GestureDetector(
        onTap: onViewAll,
        child: Text(
          'View all',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: _achievements.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) => _AchievementBadge(achievement: _achievements[i]),
        ),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final _Achievement achievement;
  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final on = achievement.unlocked;
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: on
                  ? LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: on ? null : AppColors.surfaceAlt,
              border: on ? null : Border.all(color: AppColors.border),
              boxShadow: on
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              on ? achievement.icon : Icons.lock_rounded,
              color: on ? Colors.white : AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              color: on ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: on ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
