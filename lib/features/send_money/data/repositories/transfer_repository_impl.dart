import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/offline_queue_engine.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final OfflineQueueEngine offlineQueueEngine;

  TransferRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.offlineQueueEngine,
  }) {
    // Register sync handler with shared offline engine
    offlineQueueEngine.registerHandler('send_money', (item) async {
      try {
        final model = TransferRequestModel.fromJson(item.payload);
        await remoteDataSource.submitTransfer(model);
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  @override
  Future<Result<String>> executeTransfer(TransferRequest request) async {
    final model = TransferRequestModel.fromEntity(request);
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
      // Queue offline for automatic sync
      final queueItem = QueueItem(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        featureKey: 'send_money',
        actionType: 'transfer',
        payload: model.toJson(),
        createdAt: DateTime.now(),
      );
      await offlineQueueEngine.enqueue(queueItem);
      return const Result.success(
        'QUEUED_OFFLINE: Transfer will be processed when connection resumes.',
      );
    }
  }
}
