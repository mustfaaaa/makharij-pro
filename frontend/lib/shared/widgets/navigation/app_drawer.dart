import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/current_user_display.dart';
import '../../../models/user_profile.dart';
import '../../../routes/route_names.dart';
import '../../../services/service_locator.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../ui/geometric_pattern.dart';
import '../../ui/ornaments.dart';
import '../feedback/app_dialogs.dart';

/// The side menu on Home: the places a reciter reaches less often than the
/// five tabs.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Sign out?',
      message: 'Your recitations and progress stay saved to your account.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
      isDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    // This used to navigate to Welcome without signing out, so the router's
    // redirect sent a still-signed-in user straight back to Home.
    await Services.auth.signOut();
    if (context.mounted) context.go(RoutePaths.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.primarySurface),
                  child: GeometricPattern(color: AppColors.primary, opacity: 0.07, cellSize: 40),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 20, AppSpacing.screenPadding, 20),
                  child: FutureBuilder<UserProfile?>(
                    future: Services.user.getCurrentUser().then<UserProfile?>((p) => p, onError: (_) => null),
                    builder: (context, snapshot) {
                      final name = greetingName(snapshot.data);
                      return Row(
                        children: [
                          const BrandMark(size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MakharijPro', style: AppTypography.displayText(fontSize: 22)),
                                Text(name.isEmpty ? currentUserEmail() : name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DrawerItem(icon: Icons.checklist_rounded, label: 'Practice plan', onTap: () => context.push(RoutePaths.practicePlan)),
          _DrawerItem(icon: Icons.menu_book_rounded, label: 'Tajweed rules', onTap: () => context.push(RoutePaths.tajweedRules)),
          _DrawerItem(icon: Icons.bookmark_outline_rounded, label: 'Saved', onTap: () => context.push(RoutePaths.bookmarks)),
          _DrawerItem(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.push(RoutePaths.notifications)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Divider()),
          _DrawerItem(icon: Icons.tune_rounded, label: 'Settings', onTap: () => context.push(RoutePaths.settings)),
          _DrawerItem(icon: Icons.help_outline_rounded, label: 'Help and questions', onTap: () => context.push(RoutePaths.helpFaq)),
          _DrawerItem(icon: Icons.info_outline_rounded, label: 'About', onTap: () => context.push(RoutePaths.about)),
          const Spacer(),
          SafeArea(
            top: false,
            child: _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              color: AppColors.error,
              closesFirst: false,
              onTap: () => _signOut(context),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool closesFirst;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.closesFirst = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: color ?? AppColors.textSecondary, size: 22),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w500)),
      onTap: () {
        if (closesFirst) Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
