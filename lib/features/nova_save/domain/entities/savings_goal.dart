import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

class SavingsGoal extends Equatable {
  final String id;
  final String title;
  final Money targetAmount;
  final Money currentAmount;
  final DateTime targetDate;
  final bool isLocked;

  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    this.isLocked = false,
  });

  /// Calculates the progress percentage (0 to 100) using integer arithmetic.
  int get progressPercentage {
    if (targetAmount.kobo <= 0) return 0;
    final percentage = (currentAmount.kobo * 100) ~/ targetAmount.kobo;
    return percentage > 100 ? 100 : percentage;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    targetAmount,
    currentAmount,
    targetDate,
    isLocked,
  ];
}
