import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';

class SavingsGoalModel extends SavingsGoal {
  const SavingsGoalModel({
    required super.id,
    required super.title,
    required super.targetAmount,
    required super.currentAmount,
    required super.targetDate,
    super.isLocked = false,
  });

  factory SavingsGoalModel.fromEntity(SavingsGoal entity) {
    return SavingsGoalModel(
      id: entity.id,
      title: entity.title,
      targetAmount: entity.targetAmount,
      currentAmount: entity.currentAmount,
      targetDate: entity.targetDate,
      isLocked: entity.isLocked,
    );
  }

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingsGoalModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      targetAmount: Money.fromKobo(json['target_amount_kobo'] as int? ?? 0),
      currentAmount: Money.fromKobo(json['current_amount_kobo'] as int? ?? 0),
      targetDate: DateTime.parse(
        json['target_date'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isLocked: json['is_locked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'target_amount_kobo': targetAmount.kobo,
    'current_amount_kobo': currentAmount.kobo,
    'target_date': targetDate.toIso8601String(),
    'is_locked': isLocked,
  };
}
