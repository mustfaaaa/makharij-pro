import '../dummy/dummy_notifications.dart';
import '../models/notification_item.dart';
import 'api_client.dart';

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

class ApiNotificationService implements NotificationService {
  final ApiClient _client;
  const ApiNotificationService([this._client = const ApiClient()]);

  @override
  Future<List<NotificationItem>> getNotifications() async {
    final json = await _client.get('/api/v1/notifications');
    final notifications = (json['notifications'] as List).cast<Map<String, dynamic>>();
    return notifications.map(NotificationItem.fromJson).toList();
  }
}
