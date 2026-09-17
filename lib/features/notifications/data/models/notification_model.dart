import 'dart:convert';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';

class NotificationModel extends NotificationItem {
  const NotificationModel({
    required super.id,
    required super.title,
    required super.message,
    required super.type,
    required super.timestamp,
    super.isRead = false,
    super.payload,
  });

  factory NotificationModel.fromEntity(NotificationItem item) {
    return NotificationModel(
      id: item.id,
      title: item.title,
      message: item.message,
      type: item.type,
      timestamp: item.timestamp,
      isRead: item.isRead,
      payload: item.payload,
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.transferPending,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: (map['is_read'] as int? ?? 0) == 1,
      payload: map['payload'] != null && (map['payload'] as String).isNotEmpty
          ? jsonDecode(map['payload'] as String) as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'payload': payload != null ? jsonEncode(payload) : null,
    };
  }
}
