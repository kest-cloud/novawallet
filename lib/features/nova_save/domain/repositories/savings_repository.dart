import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';

abstract class SavingsRepository {
  Future<Result<List<SavingsGoal>>> getSavingsGoals();
}
