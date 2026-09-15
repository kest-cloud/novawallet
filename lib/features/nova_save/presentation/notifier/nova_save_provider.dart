import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/create_goal_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_action_result.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_contribution_request.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/contribute_to_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/create_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/get_savings_goals_usecase.dart';
import 'package:uuid/uuid.dart';

enum NovaSaveStatus { initial, loading, loaded, submitting, error }

class NovaSaveProvider extends ChangeNotifier {
  final GetSavingsGoalsUseCase getSavingsGoalsUseCase;
  final CreateSavingsGoalUseCase createSavingsGoalUseCase;
  final ContributeToSavingsGoalUseCase contributeToSavingsGoalUseCase;

  NovaSaveProvider({
    required this.getSavingsGoalsUseCase,
    required this.createSavingsGoalUseCase,
    required this.contributeToSavingsGoalUseCase,
  }) {
    _generateAttemptIdempotencyKey();
  }

  NovaSaveStatus _status = NovaSaveStatus.initial;
  List<SavingsGoal> _goals = [];
  String? _errorMessage;
  SavingsActionResult? _lastActionResult;

  // Single idempotency key generated once per user attempt
  // Guarded against widget rebuilds.
  late String _activeIdempotencyKey;

  NovaSaveStatus get status => _status;
  List<SavingsGoal> get goals => _goals;
  String? get errorMessage => _errorMessage;
  SavingsActionResult? get lastActionResult => _lastActionResult;
  String get activeIdempotencyKey => _activeIdempotencyKey;

  bool get isLoading => _status == NovaSaveStatus.loading;
  bool get isSubmitting => _status == NovaSaveStatus.submitting;

  void _generateAttemptIdempotencyKey() {
    const uuid = Uuid();
    _activeIdempotencyKey = uuid.v4();
  }

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
        _goals = List.from(data);
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

  Future<bool> createGoal({
    required String title,
    required Money targetAmount,
    required DateTime targetDate,
    bool isLocked = false,
  }) async {
    _status = NovaSaveStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    final request = CreateGoalRequest(
      title: title,
      targetAmount: targetAmount,
      targetDate: targetDate,
      isLocked: isLocked,
      idempotencyKey: _activeIdempotencyKey,
    );

    final result = await createSavingsGoalUseCase(request);
    return result.fold(
      onSuccess: (actionResult) {
        _lastActionResult = actionResult;
        if (actionResult.updatedGoal != null) {
          _goals.add(actionResult.updatedGoal!);
        }
        _status = NovaSaveStatus.loaded;
        _generateAttemptIdempotencyKey(); // Refresh for next attempt
        notifyListeners();
        return true;
      },
      onError: (failure) {
        _errorMessage = failure.message;
        _status = NovaSaveStatus.error;
        notifyListeners();
        return false;
      },
    );
  }

  Future<bool> contributeToGoal({
    required String goalId,
    required Money amount,
  }) async {
    _status = NovaSaveStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    final request = SavingsContributionRequest(
      goalId: goalId,
      amount: amount,
      idempotencyKey: _activeIdempotencyKey,
    );

    final result = await contributeToSavingsGoalUseCase(request);
    return result.fold(
      onSuccess: (actionResult) {
        _lastActionResult = actionResult;

        // Apply optimistic/confirmed update strictly via integer addition
        final index = _goals.indexWhere((g) => g.id == goalId);
        if (index != -1) {
          final existing = _goals[index];
          _goals[index] = existing.copyWith(
            currentAmount: existing.currentAmount + amount,
          );
        }

        _status = NovaSaveStatus.loaded;
        _generateAttemptIdempotencyKey(); // Refresh for next contribution attempt
        notifyListeners();
        return true;
      },
      onError: (failure) {
        _errorMessage = failure.message;
        _status = NovaSaveStatus.error;
        notifyListeners();
        return false;
      },
    );
  }
}
