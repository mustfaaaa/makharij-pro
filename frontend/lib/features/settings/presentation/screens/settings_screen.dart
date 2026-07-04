import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/cubit/theme_cubit.dart';
import '../../../../app/cubit/verse_text_size_cubit.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/feedback/app_dialogs.dart';
import '../../../../shared/widgets/pickers/verse_text_size_picker.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/tiles/settings_tile.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeCubit>().state == ThemeMode.dark;
    final verseSize = context.watch<VerseTextSizeCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveCenter(child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            trailing: Switch(value: _notifications, onChanged: (v) => setState(() => _notifications = v), activeThumbColor: AppColors.primary),
          ),
          SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            trailing: Switch(
              value: isDark,
              onChanged: (_) => context.read<ThemeCubit>().toggle(),
              activeThumbColor: AppColors.primary,
            ),
          ),
          SettingsTile(
            icon: Icons.format_size_rounded,
            title: 'Verse Text Size',
            subtitle: 'Applies to recitation screens',
            trailing: Text(verseSize.label, style: TextStyle(color: AppColors.textSecondary)),
            onTap: () => VerseTextSizePicker.show(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SettingsTile(icon: Icons.person_outline, title: 'Edit Profile', onTap: () => context.push(RoutePaths.editProfile)),
          SettingsTile(icon: Icons.lock_outline, title: 'Change Password', onTap: () => context.push(RoutePaths.forgotPassword)),
          const SizedBox(height: AppSpacing.lg),
          Text('Support', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SettingsTile(icon: Icons.info_outline, title: 'About', onTap: () => context.push(RoutePaths.about)),
          SettingsTile(icon: Icons.help_outline, title: 'Help & FAQ', onTap: () => context.push(RoutePaths.helpFaq)),
          SettingsTile(icon: Icons.mail_outline, title: 'Contact Us', onTap: () => context.push(RoutePaths.contact)),
          const SizedBox(height: AppSpacing.lg),
          SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            iconColor: AppColors.error,
            onTap: () async {
              final confirmed = await AppDialogs.confirm(
                context,
                title: 'Logout',
                message: 'Are you sure you want to logout?',
                confirmLabel: 'Logout',
                isDestructive: true,
              );
              if (confirmed == true && context.mounted) context.go(RoutePaths.welcome);
            },
          ),
        ],
      )),
    );
  }
}
