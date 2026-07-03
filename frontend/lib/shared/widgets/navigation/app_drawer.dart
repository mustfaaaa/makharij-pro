import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../dummy/dummy_user.dart';
import '../../../routes/route_names.dart';
import '../../../theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const CircleAvatar(radius: 24, backgroundColor: AppColors.primarySurface, child: Icon(Icons.person, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dummyUser.name, style: Theme.of(context).textTheme.titleSmall),
                        Text(dummyUser.email, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _DrawerItem(icon: Icons.checklist_rounded, label: 'Practice Plan', onTap: () => context.push(RoutePaths.practicePlan)),
            _DrawerItem(icon: Icons.menu_book_rounded, label: 'Tajweed Rules', onTap: () => context.push(RoutePaths.tajweedRules)),
            _DrawerItem(icon: Icons.bookmark_outline_rounded, label: 'Bookmarks', onTap: () => context.push(RoutePaths.bookmarks)),
            _DrawerItem(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.push(RoutePaths.notifications)),
            const Divider(),
            _DrawerItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () => context.push(RoutePaths.settings)),
            _DrawerItem(icon: Icons.help_outline_rounded, label: 'Help & FAQ', onTap: () => context.push(RoutePaths.helpFaq)),
            _DrawerItem(icon: Icons.info_outline_rounded, label: 'About', onTap: () => context.push(RoutePaths.about)),
            const Spacer(),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              color: AppColors.error,
              onTap: () => context.go(RoutePaths.welcome),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary, size: 22),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
