import '../dummy/dummy_notifications.dart';
import '../models/notification_item.dart';

abstract class NotificationService {
  Future<List<NotificationItem>> getNotifications();
}

class DummyNotificationService implements NotificationService {
  @override
  Future<List<NotificationItem>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.unmodifiable(dummyNotifications);
  }
}
