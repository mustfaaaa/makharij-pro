enum NotificationType { reminder, achievement, tip, system }

NotificationType _typeFromKey(String key) {
  return NotificationType.values.firstWhere(
    (t) => t.name == key,
    orElse: () => NotificationType.system,
  );
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime dateTime;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.dateTime,
    this.isRead = false,
  });

  /// [isRead] has no backing store yet -- this is a freshly-derived status
  /// feed, not a logged/persisted one (see backend's compute_notifications),
  /// so every notification is honestly reported unread rather than guessing.
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: _typeFromKey(json['type'] as String),
      dateTime: DateTime.parse(json['dateTime'] as String),
    );
  }
}
