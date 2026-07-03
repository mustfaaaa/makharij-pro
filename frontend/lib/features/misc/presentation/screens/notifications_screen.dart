import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../dummy/dummy_notifications.dart';
import '../../../../models/notification_item.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.tip:
        return Icons.lightbulb_outline_rounded;
      case NotificationType.system:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: dummyNotifications.isEmpty
          ? const EmptyStateWidget(icon: Icons.notifications_none_rounded, title: 'No notifications', message: 'You\'re all caught up.')
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: dummyNotifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final n = dummyNotifications[i];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: n.isRead ? AppColors.surface : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Icon(_iconFor(n.type), size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(n.message, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(DateFormat.MMMd().add_jm().format(n.dateTime), style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
