import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

class CreateGoalRequest extends Equatable {
  final String title;
  final Money targetAmount;
  final DateTime targetDate;
  final bool isLocked;
  final String idempotencyKey;

  const CreateGoalRequest({
    required this.title,
    required this.targetAmount,
    required this.targetDate,
    this.isLocked = false,
    required this.idempotencyKey,
  });

  @override
  List<Object?> get props => [
    title,
    targetAmount,
    targetDate,
    isLocked,
    idempotencyKey,
  ];
}
