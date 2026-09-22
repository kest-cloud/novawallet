import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/notifications/notification_service.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final SyncEngine syncEngine;
  final WalletRepository? walletRepository;
  final NotificationService? notificationService;

  TransferRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.syncEngine,
    this.walletRepository,
    this.notificationService,
  }) {
    // Register feature action handler with the core standalone SyncEngine
    syncEngine.registerHandler(ActionType.sendMoney, (action) async {
      debugPrint(
        '[TransferRepository] [Sync Activation] Connection restored! Activating queued transfer with idempotencyKey: ${action.idempotencyKey}',
      );
      final model = TransferRequestModel.fromJson(action.payload);
      try {
        await remoteDataSource.submitTransfer(model);
        await walletRepository?.deductBalance(model.amount);
        await walletRepository?.updateTransactionStatus(
          action.idempotencyKey,
          TransactionStatus.success,
        );
        await notificationService?.notifyTransferSynced(
          idempotencyKey: action.idempotencyKey,
          amountKobo: model.amount.kobo,
          recipientName: model.recipientName,
          accountNumber: model.recipientAccountNumber,
          bankName: model.recipientBankName,
        );
        debugPrint(
          '[TransferRepository] [Sync Activation] Queued transfer synced successfully with idempotencyKey: ${action.idempotencyKey}',
        );
        return true;
      } catch (e) {
        debugPrint(
          '[TransferRepository] [Sync Activation] Queued transfer sync failed with idempotencyKey: ${action.idempotencyKey}, error: $e',
        );
        await walletRepository?.updateTransactionStatus(
          action.idempotencyKey,
          TransactionStatus.failed,
        );
        await notificationService?.notifyTransferFailed(
          idempotencyKey: action.idempotencyKey,
          amountKobo: model.amount.kobo,
          recipientName: model.recipientName,
          error: e.toString(),
        );
        rethrow;
      }
    });
  }

  @override
  Future<Result<TransferSubmissionResult>> executeTransfer(
    TransferRequest request,
  ) async {
    final model = TransferRequestModel.fromEntity(request);
    final isConnected = await networkInfo.isConnected;

    // 1. Record debit transaction in persistent history
    final recipientLabel = request.recipientName.isNotEmpty
        ? request.recipientName
        : request.recipientAccountNumber;
    final tx = Transaction(
      id: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Transfer to $recipientLabel',
      subtitle:
          '${request.recipientBankName} • ${request.recipientAccountNumber}',
      amount: request.amount,
      type: TransactionType.debit,
      status: isConnected
          ? TransactionStatus.success
          : TransactionStatus.pending,
      timestamp: DateTime.now(),
      reference: request.idempotencyKey,
    );
    await walletRepository?.recordTransaction(tx);

    if (isConnected) {
      debugPrint(
        '[TransferRepository] Executing ONLINE transfer with idempotencyKey: ${request.idempotencyKey}',
      );
      try {
        final reference = await remoteDataSource.submitTransfer(model);
        // Deduct wallet balance once online transfer is confirmed
        await walletRepository?.deductBalance(request.amount);
        return Result.success(
          TransferSubmissionResult(
            idempotencyKey: request.idempotencyKey,
            reference: reference,
            executionState: TransferExecutionState.completedOnline,
            message: 'Transfer completed successfully.',
          ),
        );
      } catch (e) {
        await walletRepository?.updateTransactionStatus(
          request.idempotencyKey,
          TransactionStatus.failed,
        );
        return Result.error(
          ServerFailure(message: 'Transfer failed: ${e.toString()}'),
        );
      }
    } else {
      // Offline: Enqueue action via core sync engine (do NOT deduct balance while pending)
      debugPrint(
        '[TransferRepository] Device OFFLINE. Enqueuing transfer with idempotencyKey: ${request.idempotencyKey}',
      );
      final action = QueuedAction.create(
        idempotencyKey: request.idempotencyKey,
        actionType: ActionType.sendMoney,
        payload: model.toJson(),
      );
      await syncEngine.enqueue(action);

      // Record pending transfer notification
      await notificationService?.notifyTransferPending(
        idempotencyKey: request.idempotencyKey,
        amountKobo: request.amount.kobo,
        recipientName: request.recipientName,
        accountNumber: request.recipientAccountNumber,
        bankName: request.recipientBankName,
      );

      return Result.success(
        TransferSubmissionResult(
          idempotencyKey: request.idempotencyKey,
          reference: 'QUEUED_${request.idempotencyKey.substring(0, 8)}',
          executionState: TransferExecutionState.queuedOffline,
          message: 'Pending — will send when back online',
        ),
      );
    }
  }
}
