import '../../../../core/base_list_cubit.dart';
import '../../../../models/notification_item.dart';
import '../../../../services/service_locator.dart';

class NotificationsCubit extends BaseListCubit<NotificationItem> {
  @override
  Future<List<NotificationItem>> fetch() => Services.notification.getNotifications();
}
