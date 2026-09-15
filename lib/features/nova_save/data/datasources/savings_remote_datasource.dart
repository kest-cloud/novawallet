import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/models/savings_goal_model.dart';

abstract class SavingsRemoteDataSource {
  Future<List<SavingsGoalModel>> fetchSavingsGoals();

  Future<SavingsGoalModel> createGoal(Map<String, dynamic> payload);

  Future<SavingsGoalModel> contributeToGoal(Map<String, dynamic> payload);
}

class SavingsRemoteDataSourceImpl implements SavingsRemoteDataSource {
  final List<SavingsGoalModel> _inMemoryGoals = [
    SavingsGoalModel(
      id: 'goal_01',
      title: 'Tech Upgrade Vault',
      targetAmount: const Money.fromKobo(50000000),
      currentAmount: const Money.fromKobo(32500000),
      targetDate: DateTime.now().add(const Duration(days: 90)),
      isLocked: true,
    ),
    SavingsGoalModel(
      id: 'goal_02',
      title: 'Emergency Rainy Day',
      targetAmount: const Money.fromKobo(100000000),
      currentAmount: const Money.fromKobo(75000000),
      targetDate: DateTime.now().add(const Duration(days: 180)),
      isLocked: false,
    ),
  ];

  @override
  Future<List<SavingsGoalModel>> fetchSavingsGoals() async {
    // Simulated remote API latency
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_inMemoryGoals);
  }

  @override
  Future<SavingsGoalModel> createGoal(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newGoal = SavingsGoalModel.fromJson(payload);
    _inMemoryGoals.add(newGoal);
    return newGoal;
  }

  @override
  Future<SavingsGoalModel> contributeToGoal(
    Map<String, dynamic> payload,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final goalId = payload['goal_id'] as String;
    final amountKobo = payload['amount_kobo'] as int;

    final index = _inMemoryGoals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final existing = _inMemoryGoals[index];
      final updated = existing.copyWith(
        currentAmount: existing.currentAmount + Money.fromKobo(amountKobo),
      );
      final updatedModel = SavingsGoalModel.fromEntity(updated);
      _inMemoryGoals[index] = updatedModel;
      return updatedModel;
    }

    throw Exception('Savings goal with id $goalId not found');
  }
}
