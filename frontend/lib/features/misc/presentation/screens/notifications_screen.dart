import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/base_list_cubit.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../models/notification_item.dart';
import '../../../../shared/widgets/loading/shimmer_placeholder.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/states/empty_state_widget.dart';
import '../../../../shared/widgets/states/error_state_widget.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../bloc/notifications_cubit.dart';

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
    return BlocProvider(
      create: (_) => NotificationsCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: ResponsiveCenter(child: BlocBuilder<NotificationsCubit, ListState<NotificationItem>>(
          builder: (context, state) {
            if (state.status == ListStatus.loading) return const ShimmerListPlaceholder(itemCount: 4, itemHeight: 84);
            if (state.status == ListStatus.error) {
              return ErrorStateWidget(message: state.errorMessage ?? 'Could not load notifications.', onRetry: () => context.read<NotificationsCubit>().load());
            }
            if (state.items.isEmpty) {
              return const EmptyStateWidget(icon: Icons.notifications_none_rounded, title: 'Nothing new', message: 'Milestones and updates will appear here.');
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xl),
              itemCount: state.items.length,
              itemBuilder: (context, i) {
                final n = state.items[i];
                final textTheme = Theme.of(context).textTheme;
                return Semantics(
                  label: '${n.isRead ? '' : 'New. '}${n.title}. ${n.message}. ${relativeTime(n.dateTime)}',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: n.type == NotificationType.achievement ? AppColors.goldWash : AppColors.primarySurface,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(_iconFor(n.type),
                              size: 20,
                              color: n.type == NotificationType.achievement ? AppColors.goldInk : AppColors.onPrimarySurface),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  style: textTheme.titleMedium?.copyWith(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(n.message, style: textTheme.bodyMedium),
                              const SizedBox(height: 6),
                              Text(relativeTime(n.dateTime), style: textTheme.labelSmall),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 6),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        )),
      ),
    );
  }
}
