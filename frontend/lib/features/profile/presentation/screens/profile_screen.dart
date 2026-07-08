import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../shared/widgets/animated/staggered_fade_slide.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../../shared/widgets/cards/section_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';

// Per-rule mastery, warm gold-family palette (consistent with the Progress
// screen). Values are the learner's mastery scores.
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

String _levelLabel(LearningLevel level) => switch (level) {
  LearningLevel.beginner => 'Beginner',
  LearningLevel.intermediate => 'Intermediate',
  LearningLevel.advanced => 'Advanced',
};

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AsyncStreamView<UserProfile>(
        stream: Services.user.watchCurrentUser(),
        errorMessage: 'Could not load your profile.',
        builder: (context, user) => _ProfileBody(user: user),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserProfile user;
  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 268,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(RoutePaths.settings),
            ),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: _ProfileHeader(
              user: user,
              onEdit: () => context.push(RoutePaths.editProfile),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaggeredFadeSlide(index: 0, child: _StatRow(user: user)),
                const SizedBox(height: 16),

                StaggeredFadeSlide(index: 1, child: const _MasteryCard()),
                const SizedBox(height: 16),

                StaggeredFadeSlide(index: 2, child: _TargetSurahsCard(surahs: user.targetSurahs)),
                const SizedBox(height: 16),

                StaggeredFadeSlide(index: 3, child: _AccountCard(joinedAt: user.joinedAt)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Gradient hero header ─────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onEdit;
  const _ProfileHeader({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentLight, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Text(
                          initial,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primarySurface, width: 2),
                          ),
                          child: Icon(Icons.edit_rounded, size: 14, color: AppColors.primaryDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderChip(
                      icon: Icons.workspace_premium_rounded,
                      label: _levelLabel(user.level),
                      solid: true,
                    ),
                    const SizedBox(width: 8),
                    _HeaderChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${user.currentStreak} day streak',
                      solid: false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool solid;
  const _HeaderChip({required this.icon, required this.label, required this.solid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: solid ? AppColors.accent : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Count-up stat row ────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final UserProfile user;
  const _StatRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(icon: Icons.graphic_eq_rounded, value: user.totalSessions.toDouble(), label: 'Sessions'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            value: user.currentStreak.toDouble(),
            suffix: 'd',
            label: 'Streak',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.percent_rounded,
            value: user.overallAccuracy,
            suffix: '%',
            label: 'Accuracy',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  final String? suffix;
  const _StatTile({required this.icon, required this.value, required this.label, this.suffix});

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
            builder: (context, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${v.round()}${suffix ?? ''}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Tajweed mastery (animated bars) ──────────────────────────────────────────

class _MasteryCard extends StatelessWidget {
  const _MasteryCard();

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
            Container(width: 10, height: 10, decoration: BoxDecoration(color: rule.color, shape: BoxShape.circle)),
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

// ── Target surahs ────────────────────────────────────────────────────────────

class _TargetSurahsCard extends StatelessWidget {
  final List<String> surahs;
  const _TargetSurahsCard({required this.surahs});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.flag_rounded,
      title: 'Target Surahs',
      subtitle: 'Surahs you\'re focusing on',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: surahs
            .map(
              (s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  s,
                  style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Account menu ─────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final DateTime joinedAt;
  const _AccountCard({required this.joinedAt});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.manage_accounts_rounded,
      title: 'Account',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        children: [
          _AccountRow(icon: Icons.edit_outlined, title: 'Edit Profile', onTap: () => context.push(RoutePaths.editProfile)),
          _divider(),
          _AccountRow(icon: Icons.checklist_rounded, title: 'Practice Plan', onTap: () => context.push(RoutePaths.practicePlan)),
          _divider(),
          _AccountRow(icon: Icons.emoji_events_outlined, title: 'Achievements', onTap: () => context.push(RoutePaths.achievements)),
          _divider(),
          _AccountRow(icon: Icons.bookmark_outline, title: 'Bookmarks', onTap: () => context.push(RoutePaths.bookmarks)),
          _divider(),
          _AccountRow(icon: Icons.settings_outlined, title: 'Settings', onTap: () => context.push(RoutePaths.settings)),
          _divider(),
          _AccountRow(
            icon: Icons.calendar_today_outlined,
            title: 'Member since',
            trailingText: DateFormat.yMMMd().format(joinedAt),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: AppColors.divider);
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final String? trailingText;
  const _AccountRow({required this.icon, required this.title, this.onTap, this.trailingText});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
          if (trailingText != null)
            Text(trailingText!, style: Theme.of(context).textTheme.bodySmall)
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, pressedScale: 0.99, child: row);
  }
}
