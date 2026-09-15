import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final SyncEngine syncEngine;

  TransferRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.syncEngine,
  }) {
    // Register feature action handler with the core standalone SyncEngine
    syncEngine.registerHandler(ActionType.sendMoney, (action) async {
      final model = TransferRequestModel.fromJson(action.payload);
      await remoteDataSource.submitTransfer(model);
      return true;
    });
  }

  @override
  Future<Result<TransferSubmissionResult>> executeTransfer(
    TransferRequest request,
  ) async {
    final model = TransferRequestModel.fromEntity(request);
    final isConnected = await networkInfo.isConnected;

    if (isConnected) {
      try {
        final reference = await remoteDataSource.submitTransfer(model);
        return Result.success(
          TransferSubmissionResult(
            idempotencyKey: request.idempotencyKey,
            reference: reference,
            executionState: TransferExecutionState.completedOnline,
            message: 'Transfer completed successfully.',
          ),
        );
      } catch (e) {
        return Result.error(
          ServerFailure(message: 'Transfer failed: ${e.toString()}'),
        );
      }
    } else {
      // Offline: Enqueue action via core sync engine
      final action = QueuedAction.create(
        idempotencyKey: request.idempotencyKey,
        actionType: ActionType.sendMoney,
        payload: model.toJson(),
      );
      await syncEngine.enqueue(action);

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
