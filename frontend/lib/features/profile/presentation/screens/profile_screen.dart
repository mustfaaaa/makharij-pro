import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/cubit/hasanah_cubit.dart';
import '../../../../core/utils/current_user_display.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../models/surah.dart';
import '../../../../models/user_profile.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/service_locator.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/animated/pressable.dart';
import '../../../../shared/widgets/feedback/app_dialogs.dart';
import '../../../../theme/app_shadows.dart';
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

  Future<void> _addTargetSurah(BuildContext context, UserProfile? profile) async {
    final surahs = await Services.surah.getSurahs();
    final current = profile?.targetSurahs ?? const [];
    final choices = surahs.where((s) => !current.contains(s.nameEnglish)).toList();
    if (!context.mounted) return;
    final chosen = await showDialog<Surah>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add a target surah'),
        children: [
          SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView.builder(
              itemCount: choices.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(choices[i].nameEnglish),
                subtitle: Text(choices[i].meaning),
                onTap: () => Navigator.pop(context, choices[i]),
              ),
            ),
          ),
        ],
      ),
    );
    if (chosen != null) {
      await Services.user.updateTargetSurahs([...current, chosen.nameEnglish]);
    }
  }

  Future<void> _removeTargetSurah(String surahName, List<String> current) async {
    await Services.user.updateTargetSurahs(current.where((s) => s != surahName).toList());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = currentUserName();
    final email = currentUserEmail();
    final bottomPad = AppSpacing.bottomNavClearance + MediaQuery.of(context).padding.bottom;

    return StreamBuilder<UserProfile>(
      stream: Services.user.watchCurrentUser(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final memberSince = profile == null ? '—' : DateFormat('MMM d, yyyy').format(profile.joinedAt);
        final targetSurahs = profile?.targetSurahs ?? const [];
        final shortId = Services.auth.currentUser?.uid.substring(0, 6).toUpperCase() ?? '——————';

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
                      boxShadow: AppShadows.sm,
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
                boxShadow: AppShadows.md,
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
                        Text('Member since $memberSince · ID: $shortId',
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              color: AppColors.textOnPrimary, size: 15),
                          const SizedBox(width: 6),
                          // "Edit", not "Edit Profile", and no hardcoded
                          // newline. The newline forced a two-line button so it
                          // would stay narrow, which read as a broken label;
                          // but the full phrase on one line takes ~167dp and
                          // leaves the "Account Details" heading 143dp, which
                          // is under the ~148dp it needs -- so the heading
                          // wrapped instead. The pencil icon inside a card
                          // titled "Account Details" already says what is being
                          // edited, so the shorter label costs no clarity and
                          // gives the heading room at every text size.
                          Text('Edit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textOnPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
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
            // Two full-width cards, not a two-up row.
            //
            // Side by side, each card had ~170dp: minus its own padding, a
            // 46dp icon and a chevron, the label was left with about 60dp and
            // "Practice Plan" broke mid-word into "Pract / ice / Plan". The
            // rule is to reflow rather than clamp meaning to keep cards
            // uniform, and stacking is the reflow that survives a large system
            // font instead of merely postponing the break.
            Pressable(
              onTap: () => context.push(RoutePaths.practicePlan),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.lgRadius,
                  boxShadow: AppShadows.md,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Practice Plan',
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('View your weekly plan',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Hasanah balance, also full width. Laid out along the row rather
            // than stacked inside a narrow column, so the figure has room to
            // read as the number it is.
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.brandCardGradient,
                ),
                borderRadius: AppRadii.lgRadius,
                boxShadow: AppShadows.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentLight,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text('ح',
                        style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HASANAH BALANCE',
                            style: TextStyle(
                                color: AppColors.textOnBrandCard
                                    .withValues(alpha: 0.85),
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 3),
                        BlocBuilder<HasanahCubit, int>(
                          builder: (context, hasanah) => Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              // Shrinks rather than wraps: a balance can grow
                              // several digits and must stay one number.
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(formatWithCommas(hasanah),
                                      maxLines: 1,
                                      style: TextStyle(
                                          color: AppColors.textOnBrandCard,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 26,
                                          height: 1.0)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('pts',
                                  style: TextStyle(
                                      color: AppColors.textOnBrandCard
                                          .withValues(alpha: 0.85),
                                      fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
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
                boxShadow: AppShadows.md,
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
                        onTap: () => _addTargetSurah(context, profile),
                        child: Text('+ Add',
                            style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (targetSurahs.isEmpty)
                    Text("Add a surah you're focusing on",
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted))
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final surah in targetSurahs)
                          GestureDetector(
                            onTap: () => _removeTargetSurah(surah, targetSurahs),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                  color: AppColors.accentLight.withValues(alpha: 0.55),
                                  borderRadius: AppRadii.pillRadius),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(surah,
                                      style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15)),
                                  const SizedBox(width: 6),
                                  Icon(Icons.close_rounded, size: 15, color: AppColors.primaryDark),
                                ],
                              ),
                            ),
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
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Expanded(
                  child: _ToolCard(
                    icon: Icons.schedule_rounded,
                    title: 'Reminders',
                    subtitle: 'Daily at 7:00 PM',
                    // Was `onTap: () {}` -- looked interactive, did nothing.
                    onTap: () => AppSnackbar.show(
                        context, 'Practice reminders are coming in a later release.'),
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
            ),
          ],
        ),
      ),
    );
      },
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
          boxShadow: AppShadows.sm,
        ),
        // Icon above the label rather than beside it. Side by side these
        // cards are half the screen, and an icon plus a gap took 56 of the
        // ~138dp inside -- enough for "Logout" at the default text size and
        // not enough for "Reminders" once the system font grows. Stacking
        // gives the label the card's full width at every scale.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, borderRadius: AppRadii.mdRadius),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(height: 10),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: titleColor, fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 2),
            Text(subtitle,
                // Two lines here, not one: "Notifications, qari" needs the
                // second line at a large text size, and there is room for it
                // now that the icon is not competing for the same row.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
