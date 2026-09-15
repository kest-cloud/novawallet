import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/models/savings_goal_model.dart';

abstract class SavingsRemoteDataSource {
  Future<List<SavingsGoalModel>> fetchSavingsGoals();
}

class SavingsRemoteDataSourceImpl implements SavingsRemoteDataSource {
  @override
  Future<List<SavingsGoalModel>> fetchSavingsGoals() async {
    // Simulated remote API response
    await Future.delayed(const Duration(milliseconds: 300));
    return [
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
  }
}
