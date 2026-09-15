import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/get_savings_goals_usecase.dart';

enum NovaSaveStatus { initial, loading, loaded, error }

class NovaSaveProvider extends ChangeNotifier {
  final GetSavingsGoalsUseCase getSavingsGoalsUseCase;

  NovaSaveProvider({required this.getSavingsGoalsUseCase});

  NovaSaveStatus _status = NovaSaveStatus.initial;
  List<SavingsGoal> _goals = [];
  String? _errorMessage;

  NovaSaveStatus get status => _status;
  List<SavingsGoal> get goals => _goals;
  String? get errorMessage => _errorMessage;

  Money get totalSavings {
    int totalKobo = 0;
    for (final g in _goals) {
      totalKobo += g.currentAmount.kobo;
    }
    return Money.fromKobo(totalKobo);
  }

  Future<void> fetchSavingsGoals() async {
    _status = NovaSaveStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await getSavingsGoalsUseCase();
    result.fold(
      onSuccess: (data) {
        _goals = data;
        _status = NovaSaveStatus.loaded;
        notifyListeners();
      },
      onError: (failure) {
        _errorMessage = failure.message;
        _status = NovaSaveStatus.error;
        notifyListeners();
      },
    );
  }
}
