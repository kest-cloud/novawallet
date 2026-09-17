import 'dart:async';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:uuid/uuid.dart';

class InAppAlert {
  final String id;
  final String title;
  final String message;
  final NotificationType type;

  const InAppAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
  });
}

class NotificationService {
  final NotificationRepository repository;
  final StreamController<InAppAlert> _alertController =
      StreamController<InAppAlert>.broadcast();
  final Uuid _uuid = const Uuid();

  NotificationService({required this.repository});

  Stream<InAppAlert> get inAppAlerts => _alertController.stream;

  Future<void> notifyTransferPending({
    required String idempotencyKey,
    required int amountKobo,
    required String recipientName,
    required String accountNumber,
    required String bankName,
  }) async {
    final amountStr = Money.fromKobo(amountKobo).formatToNaira();
    final recipient = recipientName.isNotEmpty ? recipientName : accountNumber;
    final item = NotificationItem(
      id: 'notif_${_uuid.v4()}',
      title: 'Pending Transfer Queued',
      message:
          'Transfer of $amountStr to $recipient ($bankName) is saved offline and will send automatically when connected.',
      type: NotificationType.transferPending,
      timestamp: DateTime.now(),
      payload: {
        'idempotency_key': idempotencyKey,
        'amount_kobo': amountKobo,
        'recipient_name': recipientName,
        'recipient_account_number': accountNumber,
        'recipient_bank_name': bankName,
      },
    );

    await repository.addNotification(item);
  }

  Future<void> notifyTransferSynced({
    required String idempotencyKey,
    required int amountKobo,
    required String recipientName,
    required String accountNumber,
    required String bankName,
  }) async {
    final amountStr = Money.fromKobo(amountKobo).formatToNaira();
    final recipient = recipientName.isNotEmpty ? recipientName : accountNumber;
    final item = NotificationItem(
      id: 'notif_${_uuid.v4()}',
      title: 'Transfer Sent Successfully',
      message:
          'Your queued transfer of $amountStr to $recipient ($bankName) has successfully synced and processed.',
      type: NotificationType.transferSuccess,
      timestamp: DateTime.now(),
      payload: {
        'idempotency_key': idempotencyKey,
        'amount_kobo': amountKobo,
        'recipient_name': recipientName,
        'recipient_account_number': accountNumber,
        'recipient_bank_name': bankName,
      },
    );

    await repository.addNotification(item);
    _emitInAppAlert(
      item.id,
      item.title,
      'Queued transfer of $amountStr to $recipient synced!',
      item.type,
    );
  }

  Future<void> notifyTransferFailed({
    required String idempotencyKey,
    required int amountKobo,
    required String recipientName,
    required String error,
  }) async {
    final amountStr = Money.fromKobo(amountKobo).formatToNaira();
    final item = NotificationItem(
      id: 'notif_${_uuid.v4()}',
      title: 'Transfer Failed',
      message: 'Transfer of $amountStr to $recipientName failed: $error',
      type: NotificationType.transferFailed,
      timestamp: DateTime.now(),
      payload: {
        'idempotency_key': idempotencyKey,
        'amount_kobo': amountKobo,
        'recipient_name': recipientName,
        'error': error,
      },
    );

    await repository.addNotification(item);
  }

  Future<void> notifySavingsGoalCreated({
    required String goalId,
    required String title,
    required int targetAmountKobo,
    required bool isOffline,
  }) async {
    final targetStr = Money.fromKobo(targetAmountKobo).formatToNaira();
    final item = NotificationItem(
      id: 'notif_${_uuid.v4()}',
      title: isOffline ? 'Savings Vault Queued' : 'Savings Vault Created',
      message: isOffline
          ? 'Target vault "$title" ($targetStr) will sync when back online.'
          : 'New target vault "$title" with target $targetStr has been created.',
      type: NotificationType.savingsGoalCreated,
      timestamp: DateTime.now(),
      payload: {
        'goal_id': goalId,
        'title': title,
        'target_amount_kobo': targetAmountKobo,
      },
    );

    await repository.addNotification(item);
    if (!isOffline) {
      _emitInAppAlert(
        item.id,
        item.title,
        'Vault "$title" created successfully!',
        item.type,
      );
    }
  }

  Future<void> notifySavingsContributed({
    required String goalId,
    required String goalTitle,
    required int amountKobo,
    required bool isOffline,
  }) async {
    final amountStr = Money.fromKobo(amountKobo).formatToNaira();
    final item = NotificationItem(
      id: 'notif_${_uuid.v4()}',
      title: isOffline ? 'Deposit Queued' : 'Vault Contribution Successful',
      message: isOffline
          ? 'Deposit of $amountStr to "$goalTitle" is queued offline and will sync automatically.'
          : 'Successfully deposited $amountStr to your "$goalTitle" savings vault.',
      type: NotificationType.savingsContributed,
      timestamp: DateTime.now(),
      payload: {
        'goal_id': goalId,
        'goal_title': goalTitle,
        'amount_kobo': amountKobo,
      },
    );

    await repository.addNotification(item);
    if (!isOffline) {
      _emitInAppAlert(
        item.id,
        item.title,
        'Deposited $amountStr to $goalTitle',
        item.type,
      );
    }
  }

  void _emitInAppAlert(
    String id,
    String title,
    String message,
    NotificationType type,
  ) {
    if (!_alertController.isClosed) {
      _alertController.add(
        InAppAlert(id: id, title: title, message: message, type: type),
      );
    }
  }

  void dispose() {
    _alertController.close();
  }
}
