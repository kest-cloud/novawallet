import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';

class SendMoneyUseCase {
  final TransferRepository repository;

  const SendMoneyUseCase(this.repository);

  Future<Result<String>> call(TransferRequest request) async {
    if (request.recipientAccountNumber.trim().length != 10) {
      return const Result.error(
        ValidationFailure(
          message: 'Recipient account number must be exactly 10 digits.',
        ),
      );
    }
    if (!request.amount.isPositive) {
      return const Result.error(
        ValidationFailure(
          message: 'Transfer amount must be greater than zero.',
        ),
      );
    }
    return repository.executeTransfer(request);
  }
}
