import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/notifications/notification_service.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/datasources/savings_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/models/savings_goal_model.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/create_goal_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_action_result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_contribution_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';
import 'package:uuid/uuid.dart';

class SavingsRepositoryImpl implements SavingsRepository {
  final SavingsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final SyncEngine syncEngine;
  final WalletRepository? walletRepository;
  final SyncDatabaseHelper? dbHelper;
  final NotificationService? notificationService;

  SavingsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.syncEngine,
    this.walletRepository,
    this.dbHelper,
    this.notificationService,
  }) {
    // Register feature handlers with core SyncEngine
    syncEngine.registerHandler(ActionType.createSavingsGoal, (action) async {
      await remoteDataSource.createGoal(action.payload);
      final model = SavingsGoalModel.fromJson(action.payload);
      await dbHelper?.insertOrUpdateSavingsGoal(model);
      await notificationService?.notifySavingsGoalCreated(
        goalId: model.id,
        title: model.title,
        targetAmountKobo: model.targetAmount.kobo,
        isOffline: false,
      );
      return true;
    });

    syncEngine.registerHandler(ActionType.contributeSavings, (action) async {
      try {
        await remoteDataSource.contributeToGoal(action.payload);
        final goalId = action.payload['goal_id'] as String;
        final amountKobo = action.payload['amount_kobo'] as int;
        await dbHelper?.contributeToSavingsGoal(goalId, amountKobo);
        await walletRepository?.deductBalance(Money.fromKobo(amountKobo));
        await walletRepository?.updateTransactionStatus(
          action.idempotencyKey,
          TransactionStatus.success,
        );
        await notificationService?.notifySavingsContributed(
          goalId: goalId,
          goalTitle: 'NovaSave Vault',
          amountKobo: amountKobo,
          isOffline: false,
        );
        return true;
      } catch (e) {
        await walletRepository?.updateTransactionStatus(
          action.idempotencyKey,
          TransactionStatus.failed,
        );
        rethrow;
      }
    });
  }

  @override
  Future<Result<List<SavingsGoal>>> getSavingsGoals() async {
    try {
      if (dbHelper != null) {
        final goals = await dbHelper!.getSavingsGoals();
        return Result.success(goals);
      }

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
        await dbHelper?.insertOrUpdateSavingsGoal(model);
        await notificationService?.notifySavingsGoalCreated(
          goalId: model.id,
          title: model.title,
          targetAmountKobo: model.targetAmount.kobo,
          isOffline: false,
        );
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
      await dbHelper?.insertOrUpdateSavingsGoal(optimisticGoal);

      await notificationService?.notifySavingsGoalCreated(
        goalId: optimisticGoal.id,
        title: optimisticGoal.title,
        targetAmountKobo: optimisticGoal.targetAmount.kobo,
        isOffline: true,
      );

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

    // 1. Record debit transaction in transaction history
    final tx = Transaction(
      id: 'TXN_SAVE_${DateTime.now().millisecondsSinceEpoch}',
      title: 'NovaSave Contribution',
      subtitle: 'Savings Vault Deposit',
      amount: request.amount,
      type: TransactionType.debit,
      status: isConnected
          ? TransactionStatus.success
          : TransactionStatus.pending,
      timestamp: DateTime.now(),
      reference: request.idempotencyKey,
    );
    await walletRepository?.recordTransaction(tx);

    if (isConnected) {
      try {
        final updatedGoal = await remoteDataSource.contributeToGoal(payload);
        await dbHelper?.insertOrUpdateSavingsGoal(updatedGoal);
        await dbHelper?.contributeToSavingsGoal(
          request.goalId,
          request.amount.kobo,
        );
        // Deduct wallet balance once online contribution succeeds
        await walletRepository?.deductBalance(request.amount);

        await notificationService?.notifySavingsContributed(
          goalId: request.goalId,
          goalTitle: updatedGoal.title,
          amountKobo: request.amount.kobo,
          isOffline: false,
        );

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
        await walletRepository?.updateTransactionStatus(
          request.idempotencyKey,
          TransactionStatus.failed,
        );
        return Result.error(
          ServerFailure(message: 'Failed to contribute: ${e.toString()}'),
        );
      }
    } else {
      // Offline: Enqueue to standalone SyncEngine (do NOT deduct balance while pending)
      final action = QueuedAction.create(
        idempotencyKey: request.idempotencyKey,
        actionType: ActionType.contributeSavings,
        payload: payload,
      );
      await syncEngine.enqueue(action);

      await notificationService?.notifySavingsContributed(
        goalId: request.goalId,
        goalTitle: 'NovaSave Vault',
        amountKobo: request.amount.kobo,
        isOffline: true,
      );

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
