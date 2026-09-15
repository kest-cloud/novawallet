import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';

enum SavingsExecutionState { completedOnline, queuedOffline }

class SavingsActionResult extends Equatable {
  final String idempotencyKey;
  final SavingsGoal? updatedGoal;
  final SavingsExecutionState executionState;
  final String message;

  const SavingsActionResult({
    required this.idempotencyKey,
    this.updatedGoal,
    required this.executionState,
    required this.message,
  });

  bool get isQueuedOffline =>
      executionState == SavingsExecutionState.queuedOffline;
  bool get isCompletedOnline =>
      executionState == SavingsExecutionState.completedOnline;

  @override
  List<Object?> get props => [
    idempotencyKey,
    updatedGoal,
    executionState,
    message,
  ];
}
