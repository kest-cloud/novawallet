import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';

class SendMoneyUseCase {
  final TransferRepository repository;

  const SendMoneyUseCase(this.repository);

  Future<Result<TransferSubmissionResult>> call(TransferRequest request) async {
    final sanitizedAccount = request.recipientAccountNumber.replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (sanitizedAccount.length != 10) {
      return const Result.error(
        ValidationFailure(
          message: 'Recipient account number must be exactly 10 digits.',
        ),
      );
    }
    if (request.recipientName.trim().isEmpty) {
      return const Result.error(
        ValidationFailure(message: 'Recipient name cannot be empty.'),
      );
    }
    if (!request.amount.isPositive) {
      return const Result.error(
        ValidationFailure(
          message: 'Transfer amount must be greater than ₦0.00.',
        ),
      );
    }
    if (request.idempotencyKey.trim().isEmpty) {
      return const Result.error(
        ValidationFailure(
          message:
              'A valid idempotency key is required for this transfer attempt.',
        ),
      );
    }

    return repository.executeTransfer(
      request.copyWith(recipientAccountNumber: sanitizedAccount),
    );
  }
}
