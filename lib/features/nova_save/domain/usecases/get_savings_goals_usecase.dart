import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';

class GetSavingsGoalsUseCase {
  final SavingsRepository repository;

  const GetSavingsGoalsUseCase(this.repository);

  Future<Result<List<SavingsGoal>>> call() {
    return repository.getSavingsGoals();
  }
}
