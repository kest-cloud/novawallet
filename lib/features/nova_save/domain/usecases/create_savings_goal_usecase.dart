import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/create_goal_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_action_result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';

class CreateSavingsGoalUseCase {
  final SavingsRepository repository;

  const CreateSavingsGoalUseCase(this.repository);

  Future<Result<SavingsActionResult>> call(CreateGoalRequest request) async {
    if (request.title.trim().isEmpty) {
      return const Result.error(
        ValidationFailure(message: 'Vault title cannot be empty.'),
      );
    }
    if (!request.targetAmount.isPositive) {
      return const Result.error(
        ValidationFailure(message: 'Target amount must be greater than ₦0.00.'),
      );
    }
    if (request.idempotencyKey.trim().isEmpty) {
      return const Result.error(
        ValidationFailure(
          message: 'A valid idempotency key is required to create a vault.',
        ),
      );
    }

    return repository.createSavingsGoal(request);
  }
}
