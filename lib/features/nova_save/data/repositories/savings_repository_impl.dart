import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/datasources/savings_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/models/savings_goal_model.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/create_goal_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_action_result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_contribution_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';
import 'package:uuid/uuid.dart';

class SavingsRepositoryImpl implements SavingsRepository {
  final SavingsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final SyncEngine syncEngine;

  SavingsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.syncEngine,
  }) {
    // Register feature handlers with core SyncEngine
    syncEngine.registerHandler(ActionType.createSavingsGoal, (action) async {
      await remoteDataSource.createGoal(action.payload);
      return true;
    });

    syncEngine.registerHandler(ActionType.contributeSavings, (action) async {
      await remoteDataSource.contributeToGoal(action.payload);
      return true;
    });
  }

  @override
  Future<Result<List<SavingsGoal>>> getSavingsGoals() async {
    try {
      final goals = await remoteDataSource.fetchSavingsGoals();
      return Result.success(goals);
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Failed to load savings goals: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<SavingsActionResult>> createSavingsGoal(
    CreateGoalRequest request,
  ) async {
    const uuid = Uuid();
    final goalId = 'goal_${uuid.v4().substring(0, 8)}';
    final payload = {
      'id': goalId,
      'title': request.title,
      'target_amount_kobo': request.targetAmount.kobo,
      'current_amount_kobo': 0,
      'target_date': request.targetDate.toIso8601String(),
      'is_locked': request.isLocked,
      'idempotency_key': request.idempotencyKey,
    };

    final isConnected = await networkInfo.isConnected;

    if (isConnected) {
      try {
        final model = await remoteDataSource.createGoal(payload);
        return Result.success(
          SavingsActionResult(
            idempotencyKey: request.idempotencyKey,
            updatedGoal: model,
            executionState: SavingsExecutionState.completedOnline,
            message: 'Savings vault created successfully.',
          ),
        );
      } catch (e) {
        return Result.error(
          ServerFailure(message: 'Failed to create goal: ${e.toString()}'),
        );
      }
    } else {
      // Offline: Enqueue to standalone SyncEngine
      final action = QueuedAction.create(
        idempotencyKey: request.idempotencyKey,
        actionType: ActionType.createSavingsGoal,
        payload: payload,
      );
      await syncEngine.enqueue(action);

      final optimisticGoal = SavingsGoalModel.fromJson(payload);
      return Result.success(
        SavingsActionResult(
          idempotencyKey: request.idempotencyKey,
          updatedGoal: optimisticGoal,
          executionState: SavingsExecutionState.queuedOffline,
          message: 'Pending — will create when back online',
        ),
      );
    }
  }

  @override
  Future<Result<SavingsActionResult>> contributeToGoal(
    SavingsContributionRequest request,
  ) async {
    final payload = {
      'goal_id': request.goalId,
      'amount_kobo': request.amount.kobo,
      'idempotency_key': request.idempotencyKey,
    };

    final isConnected = await networkInfo.isConnected;

    if (isConnected) {
      try {
        final updatedGoal = await remoteDataSource.contributeToGoal(payload);
        return Result.success(
          SavingsActionResult(
            idempotencyKey: request.idempotencyKey,
            updatedGoal: updatedGoal,
            executionState: SavingsExecutionState.completedOnline,
            message:
                'Contribution of ${request.amount.formatToNaira()} successful.',
          ),
        );
      } catch (e) {
        return Result.error(
          ServerFailure(message: 'Failed to contribute: ${e.toString()}'),
        );
      }
    } else {
      // Offline: Enqueue to standalone SyncEngine
      final action = QueuedAction.create(
        idempotencyKey: request.idempotencyKey,
        actionType: ActionType.contributeSavings,
        payload: payload,
      );
      await syncEngine.enqueue(action);

      return Result.success(
        SavingsActionResult(
          idempotencyKey: request.idempotencyKey,
          executionState: SavingsExecutionState.queuedOffline,
          message: 'Pending — will send when back online',
        ),
      );
    }
  }
}
