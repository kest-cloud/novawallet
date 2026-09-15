import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';
import 'package:uuid/uuid.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final SyncEngine syncEngine;

  TransferRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.syncEngine,
  }) {
    // Register action handler with the standalone SyncEngine
    syncEngine.registerHandler(ActionType.sendMoney, (action) async {
      final model = TransferRequestModel.fromJson(action.payload);
      await remoteDataSource.submitTransfer(model);
      return true;
    });
  }

  @override
  Future<Result<String>> executeTransfer(TransferRequest request) async {
    final idempotencyKey = const Uuid().v4();
    final model = TransferRequestModel.fromEntity(
      request,
    ).copyWith(reference: idempotencyKey);
    final isConnected = await networkInfo.isConnected;

    if (isConnected) {
      try {
        final reference = await remoteDataSource.submitTransfer(model);
        return Result.success(reference);
      } catch (e) {
        return Result.error(
          ServerFailure(message: 'Transfer failed: ${e.toString()}'),
        );
      }
    } else {
      // Queue offline for automatic sync replay
      final action = QueuedAction.create(
        actionType: ActionType.sendMoney,
        idempotencyKey: idempotencyKey,
        payload: model.toJson(),
      );
      await syncEngine.enqueue(action);
      return Result.success(
        'QUEUED_OFFLINE: Transfer with idempotency key $idempotencyKey queued. Will send when back online.',
      );
    }
  }
}
