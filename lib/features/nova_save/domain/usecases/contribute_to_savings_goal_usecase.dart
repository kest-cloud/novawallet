import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_action_result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_contribution_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';

class ContributeToSavingsGoalUseCase {
  final SavingsRepository repository;

  const ContributeToSavingsGoalUseCase(this.repository);

  Future<Result<SavingsActionResult>> call(
    SavingsContributionRequest request,
  ) async {
    if (request.goalId.trim().isEmpty) {
      return const Result.error(
        ValidationFailure(message: 'A valid savings goal ID is required.'),
      );
    }
    if (!request.amount.isPositive) {
      return const Result.error(
        ValidationFailure(
          message: 'Contribution amount must be greater than ₦0.00.',
        ),
      );
    }
    if (request.idempotencyKey.trim().isEmpty) {
      return const Result.error(
        ValidationFailure(
          message: 'A valid idempotency key is required for contribution.',
        ),
      );
    }

    return repository.contributeToGoal(request);
  }
}
