import 'dart:async';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/features/notifications/data/models/notification_model.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final SyncDatabaseHelper dbHelper;
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  final StreamController<List<NotificationItem>> _notificationsController =
      StreamController<List<NotificationItem>>.broadcast();

  NotificationRepositoryImpl({required this.dbHelper});

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    return await dbHelper.getNotifications(limit: limit);
  }

  @override
  Future<void> addNotification(NotificationItem notification) async {
    final model = NotificationModel.fromEntity(notification);
    await dbHelper.insertNotification(model);
    await _notifyChange();
  }

  @override
  Future<void> markAsRead(String id) async {
    await dbHelper.markNotificationAsRead(id);
    await _notifyChange();
  }

  @override
  Future<void> markAllAsRead() async {
    await dbHelper.markAllNotificationsAsRead();
    await _notifyChange();
  }

  @override
  Future<int> getUnreadCount() async {
    return await dbHelper.getUnreadNotificationsCount();
  }

  @override
  Stream<int> watchUnreadCount() {
    // Emit initial count on first listen
    _emitCurrentUnreadCount();
    return _unreadCountController.stream;
  }

  @override
  Stream<List<NotificationItem>> watchNotifications() {
    _emitCurrentNotifications();
    return _notificationsController.stream;
  }

  @override
  Future<void> removePendingNotification(String idempotencyKey) async {
    await dbHelper.deletePendingNotificationByIdempotencyKey(idempotencyKey);
    await _notifyChange();
  }

  @override
  Future<void> clearAll() async {
    await dbHelper.clearAllNotifications();
    await _notifyChange();
  }

  Future<void> _notifyChange() async {
    await _emitCurrentUnreadCount();
    await _emitCurrentNotifications();
  }

  Future<void> _emitCurrentUnreadCount() async {
    if (!_unreadCountController.isClosed) {
      final count = await getUnreadCount();
      _unreadCountController.add(count);
    }
  }

  Future<void> _emitCurrentNotifications() async {
    if (!_notificationsController.isClosed) {
      final notifs = await getNotifications();
      _notificationsController.add(notifs);
    }
  }

  void dispose() {
    _unreadCountController.close();
    _notificationsController.close();
  }
}
