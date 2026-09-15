import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

/// Pure domain entity representing a target savings vault.
///
/// CRITICAL: All progress percentage calculations are computed strictly using
/// 64-bit integer arithmetic on raw Kobo values to eliminate floating-point drift.
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
  ///
  /// Example: (25,000 kobo * 100) ~/ 50,000 kobo = 50%
  int get progressPercentage {
    if (targetAmount.kobo <= 0) return 0;
    final percentage = (currentAmount.kobo * 100) ~/ targetAmount.kobo;
    return percentage > 100 ? 100 : percentage;
  }

  /// Calculates progress in basis points (0 to 10000, where 100 bps = 1.00%).
  /// Enables precise sub-percentage formatting without floating-point math.
  int get progressBasisPoints {
    if (targetAmount.kobo <= 0) return 0;
    final bps = (currentAmount.kobo * 10000) ~/ targetAmount.kobo;
    return bps > 10000 ? 10000 : bps;
  }

  /// Formatted progress percentage string for presentation (e.g. "45%").
  String get progressPercentageFormatted => '$progressPercentage%';

  /// Returns true if the goal has reached or exceeded 100% of target.
  bool get isCompleted => currentAmount.kobo >= targetAmount.kobo;

  /// Remaining amount needed to reach the target amount.
  Money get remainingAmount {
    if (currentAmount.kobo >= targetAmount.kobo) return Money.zero;
    return targetAmount - currentAmount;
  }

  SavingsGoal copyWith({
    String? id,
    String? title,
    Money? targetAmount,
    Money? currentAmount,
    DateTime? targetDate,
    bool? isLocked,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      isLocked: isLocked ?? this.isLocked,
    );
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
