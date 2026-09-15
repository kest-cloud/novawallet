import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';

abstract class TransferRemoteDataSource {
  Future<String> submitTransfer(TransferRequestModel request);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  @override
  Future<String> submitTransfer(TransferRequestModel request) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return 'TXN_${DateTime.now().millisecondsSinceEpoch}';
  }
}
