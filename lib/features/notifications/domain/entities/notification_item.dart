import 'package:equatable/equatable.dart';

enum NotificationType {
  transferPending,
  transferSuccess,
  transferFailed,
  savingsGoalCreated,
  savingsContributed;

  String get displayName {
    switch (this) {
      case NotificationType.transferPending:
        return 'Pending Send';
      case NotificationType.transferSuccess:
        return 'Transfer Synced';
      case NotificationType.transferFailed:
        return 'Transfer Failed';
      case NotificationType.savingsGoalCreated:
        return 'Vault Created';
      case NotificationType.savingsContributed:
        return 'Vault Deposit';
    }
  }

  String get category {
    switch (this) {
      case NotificationType.transferPending:
      case NotificationType.transferSuccess:
      case NotificationType.transferFailed:
        return 'transfers';
      case NotificationType.savingsGoalCreated:
      case NotificationType.savingsContributed:
        return 'savings';
    }
  }

  bool get isPending => this == NotificationType.transferPending;
}

class NotificationItem extends Equatable {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? payload;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? payload,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        message,
        type,
        timestamp,
        isRead,
        payload,
      ];
}
