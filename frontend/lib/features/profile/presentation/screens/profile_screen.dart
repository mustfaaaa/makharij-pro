import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../core/utils/current_user_display.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../dummy/dummy_user.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../shared/widgets/feedback/app_dialogs.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

/// Profile tab rebuilt to the provided mockup: gold-ringed avatar with the
/// reciter level, Account Details with Edit Profile, the Practice Plan +
/// Hasanah Balance pair, Target Surahs chips, and the App Tools & Info grid
/// (Bookmarks, Settings, Reminders, Logout).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Logout',
      message: 'Are you sure you want to log out of MakharijPro AI?',
      confirmLabel: 'Logout',
      isDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await Services.auth.signOut();
    } catch (_) {
      // Signing out of the dummy/local session can't really fail; ignore.
    }
    if (context.mounted) context.go(RoutePaths.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = currentUserName();
    final email = currentUserEmail();
    final memberSince = DateFormat('MMM d, yyyy').format(dummyUser.joinedAt);
    final bottomPad = AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 12, AppSpacing.screenPadding, bottomPad),
          children: [
            // ── Header: gold-ringed avatar + name + settings gear ────────
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'M',
                    style: TextStyle(
                        color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('Intermediate reciter',
                              style:
                                  textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Pressable(
                  onTap: () => context.push(RoutePaths.settings),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))
                      ],
                    ),
                    child: Icon(Icons.settings_rounded, color: AppColors.textSecondary, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Account Details ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.lgRadius,
                boxShadow: [
                  BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Details',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Member since $memberSince · ID: MP-0160',
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    onTap: () => context.push(RoutePaths.editProfile),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration:
                          BoxDecoration(color: AppColors.primary, borderRadius: AppRadii.lgRadius),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text('Edit\nProfile',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  height: 1.2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Your Practice & Plan ─────────────────────────────────────
            Text('Your Practice & Plan',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Practice Plan card
                  Expanded(
                    child: Pressable(
                      onTap: () => context.push(RoutePaths.practicePlan),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.lgRadius,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: AppRadii.mdRadius),
                              child: Icon(Icons.checklist_rounded,
                                  color: AppColors.primaryDark, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Practice Plan',
                                      style: textTheme.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800)),
                                  Text('View your weekly plan',
                                      style: textTheme.bodySmall
                                          ?.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: AppColors.textMuted, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Hasanah Balance card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryLight, const Color(0xFF8B6914)],
                        ),
                        borderRadius: AppRadii.lgRadius,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Hasanah\nBalance',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1.25)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentLight,
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.7), width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text('ح',
                                    style: TextStyle(
                                        color: const Color(0xFF8B6914),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: BlocBuilder<HasanahCubit, int>(
                                  builder: (context, hasanah) => Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(formatWithCommas(hasanah),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 22,
                                                height: 1.0)),
                                      ),
                                      Text('pts',
                                          style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontSize: 12)),
                                    ],
                                  ),
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
            ),
            const SizedBox(height: 12),
            // ── Target Surahs ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.lgRadius,
                boxShadow: [
                  BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: AppColors.primarySurface, borderRadius: AppRadii.mdRadius),
                        child:
                            Icon(Icons.flag_outlined, color: AppColors.primaryDark, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Surahs',
                                style:
                                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            Text("Surahs you're focusing on",
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Text('+ Add',
                            style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      for (final surah in dummyUser.targetSurahs)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                              color: AppColors.accentLight.withValues(alpha: 0.55),
                              borderRadius: AppRadii.pillRadius),
                          child: Text(surah,
                              style: TextStyle(
                                  color: const Color(0xFF8B6914),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── App Tools & Info ─────────────────────────────────────────
            Text('App Tools & Info',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _ToolCard(
                    icon: Icons.bookmark_rounded,
                    title: 'Bookmarks',
                    subtitle: '15 saved',
                    onTap: () => context.push(RoutePaths.bookmarks),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ToolCard(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'Notifications, qari',
                    onTap: () => context.push(RoutePaths.settings),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToolCard(
                    icon: Icons.schedule_rounded,
                    title: 'Reminders',
                    subtitle: 'Daily at 7:00 PM',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ToolCard(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'See you soon',
                    destructive: true,
                    onTap: () => _logout(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tool grid card ────────────────────────────────────────────────────────────
class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive ? AppColors.error : AppColors.textPrimary;
    final iconBg = destructive ? AppColors.errorLight : AppColors.primarySurface;
    final iconColor = destructive ? AppColors.error : AppColors.primaryDark;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.lgRadius,
          boxShadow: [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: iconBg, borderRadius: AppRadii.mdRadius),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor, fontWeight: FontWeight.w800, fontSize: 15.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
