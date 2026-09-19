import 'package:intl/intl.dart';

/// "just now", "12 minutes ago", "yesterday", "3 days ago", then a date.
/// Plain words for when something happened; nothing fake-precise.
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24 && current.day == time.day) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  final days = DateTime(current.year, current.month, current.day)
      .difference(DateTime(time.year, time.month, time.day))
      .inDays;
  if (days <= 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return DateFormat.MMMd().format(time);
}
