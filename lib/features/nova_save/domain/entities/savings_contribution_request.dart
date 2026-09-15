import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

class SavingsContributionRequest extends Equatable {
  final String goalId;
  final Money amount;
  final String idempotencyKey;

  const SavingsContributionRequest({
    required this.goalId,
    required this.amount,
    required this.idempotencyKey,
  });

  @override
  List<Object?> get props => [goalId, amount, idempotencyKey];
}
