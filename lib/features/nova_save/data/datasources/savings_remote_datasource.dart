import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/models/savings_goal_model.dart';

abstract class SavingsRemoteDataSource {
  Future<List<SavingsGoalModel>> fetchSavingsGoals();

  Future<SavingsGoalModel> createGoal(Map<String, dynamic> payload);

  Future<SavingsGoalModel> contributeToGoal(Map<String, dynamic> payload);
}

class SavingsRemoteDataSourceImpl implements SavingsRemoteDataSource {
  // Starts completely empty initially until goals are created by user
  final List<SavingsGoalModel> _inMemoryGoals = [];

  SavingsRemoteDataSourceImpl({List<SavingsGoalModel>? initialGoals}) {
    if (initialGoals != null) {
      _inMemoryGoals.addAll(initialGoals);
    }
  }

  @override
  Future<List<SavingsGoalModel>> fetchSavingsGoals() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_inMemoryGoals);
  }

  @override
  Future<SavingsGoalModel> createGoal(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newGoal = SavingsGoalModel.fromJson(payload);
    _inMemoryGoals.removeWhere((g) => g.id == newGoal.id);
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
      final updated = SavingsGoalModel.fromEntity(
        existing.copyWith(
          currentAmount: existing.currentAmount + Money.fromKobo(amountKobo),
        ),
      );
      _inMemoryGoals[index] = updated;
      return updated;
    } else {
      final newGoal = SavingsGoalModel(
        id: goalId,
        title: 'Savings Goal',
        targetAmount: Money.fromKobo(amountKobo * 2),
        currentAmount: Money.fromKobo(amountKobo),
        targetDate: DateTime.now().add(const Duration(days: 90)),
        isLocked: false,
      );
      _inMemoryGoals.add(newGoal);
      return newGoal;
    }
  }
}
