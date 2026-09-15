import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';

abstract class TransferRemoteDataSource {
  Future<String> submitTransfer(TransferRequestModel request);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final Duration latency;
  final List<String> processedIdempotencyKeys = [];

  TransferRemoteDataSourceImpl({
    this.latency = const Duration(milliseconds: 400),
  });

  @override
  Future<String> submitTransfer(TransferRequestModel request) async {
    await Future.delayed(latency);
    processedIdempotencyKeys.add(request.idempotencyKey);
    return 'TXN_NIP_${DateTime.now().millisecondsSinceEpoch}';
  }
}
