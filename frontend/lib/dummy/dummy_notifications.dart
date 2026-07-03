import '../models/notification_item.dart';

final List<NotificationItem> dummyNotifications = [
  NotificationItem(
    id: 'n1',
    title: 'Time to practice!',
    message: 'You haven\'t recited today. Keep your 12-day streak alive.',
    type: NotificationType.reminder,
    dateTime: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  NotificationItem(
    id: 'n2',
    title: 'Achievement unlocked',
    message: 'You earned "Surah Explorer" for reciting 10 different surahs.',
    type: NotificationType.achievement,
    dateTime: DateTime.now().subtract(const Duration(hours: 5)),
    isRead: true,
  ),
  NotificationItem(
    id: 'n3',
    title: 'Tajweed Tip',
    message: 'Struggling with Ghunnah? Try holding the nasal sound for a full two counts.',
    type: NotificationType.tip,
    dateTime: DateTime.now().subtract(const Duration(days: 1)),
  ),
  NotificationItem(
    id: 'n4',
    title: 'Weekly summary ready',
    message: 'Your progress report for this week is now available.',
    type: NotificationType.system,
    dateTime: DateTime.now().subtract(const Duration(days: 2)),
    isRead: true,
  ),
];
