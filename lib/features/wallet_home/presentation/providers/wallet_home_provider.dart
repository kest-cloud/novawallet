import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_wallet_balance_usecase.dart';

enum WalletHomeStatus { initial, loading, loaded, error }

class WalletHomeProvider extends ChangeNotifier {
  final GetWalletBalanceUseCase getWalletBalanceUseCase;

  WalletHomeProvider({required this.getWalletBalanceUseCase});

  WalletHomeStatus _status = WalletHomeStatus.initial;
  WalletBalance? _walletBalance;
  String? _errorMessage;
  bool _isBalanceHidden = false;

  WalletHomeStatus get status => _status;
  WalletBalance? get walletBalance => _walletBalance;
  String? get errorMessage => _errorMessage;
  bool get isBalanceHidden => _isBalanceHidden;

  Money get availableBalance => _walletBalance?.availableBalance ?? Money.zero;

  void toggleBalanceVisibility() {
    _isBalanceHidden = !_isBalanceHidden;
    notifyListeners();
  }

  Future<void> fetchWalletBalance() async {
    _status = WalletHomeStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await getWalletBalanceUseCase();
    result.fold(
      onSuccess: (balance) {
        _walletBalance = balance;
        _status = WalletHomeStatus.loaded;
        notifyListeners();
      },
      onError: (failure) {
        _errorMessage = failure.message;
        _status = WalletHomeStatus.error;
        notifyListeners();
      },
    );
  }
}
