import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class ProfileTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const ProfileTile({super.key, required this.name, required this.subtitle, this.avatarUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primarySurface,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.primary) : null,
      ),
      title: Text(name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
    );
  }
}
