import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/create_goal_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_action_result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_contribution_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';

/// Pure domain repository contract for Nova Save feature.
abstract class SavingsRepository {
  Future<Result<List<SavingsGoal>>> getSavingsGoals();

  Future<Result<SavingsActionResult>> createSavingsGoal(
    CreateGoalRequest request,
  );

  Future<Result<SavingsActionResult>> contributeToGoal(
    SavingsContributionRequest request,
  );
}
