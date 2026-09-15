import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';

abstract class TransferRepository {
  Future<Result<String>> executeTransfer(TransferRequest request);
}
