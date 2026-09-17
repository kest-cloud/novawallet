import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> getNotifications({int limit = 50});
  Future<void> addNotification(NotificationItem notification);
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<int> getUnreadCount();
  Stream<int> watchUnreadCount();
  Stream<List<NotificationItem>> watchNotifications();
  Future<void> clearAll();
}
