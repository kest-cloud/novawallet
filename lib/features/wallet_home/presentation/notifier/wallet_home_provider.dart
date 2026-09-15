import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_recent_transactions_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_wallet_balance_usecase.dart';

enum WalletHomeStatus { initial, loading, loaded, error }

class WalletHomeProvider extends ChangeNotifier {
  final GetWalletBalanceUseCase getWalletBalanceUseCase;
  final GetRecentTransactionsUseCase getRecentTransactionsUseCase;
  final SyncEngine? syncEngine;

  StreamSubscription<int>? _syncSubscription;
  bool _isDisposed = false;

  WalletHomeProvider({
    required this.getWalletBalanceUseCase,
    required this.getRecentTransactionsUseCase,
    this.syncEngine,
  }) {
    _initSyncListener();
  }

  WalletHomeStatus _status = WalletHomeStatus.initial;
  WalletBalance? _walletBalance;
  List<Transaction> _transactions = [];
  String? _errorMessage;
  bool _isBalanceHidden = false;
  int _pendingSyncCount = 0;

  WalletHomeStatus get status => _status;
  WalletBalance? get walletBalance => _walletBalance;
  List<Transaction> get transactions => _transactions;
  String? get errorMessage => _errorMessage;
  bool get isBalanceHidden => _isBalanceHidden;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _status == WalletHomeStatus.loading;

  Money get availableBalance => _walletBalance?.availableBalance ?? Money.zero;

  void _initSyncListener() {
    if (syncEngine != null) {
      _syncSubscription = syncEngine!.pendingCountStream.listen((count) {
        if (!_isDisposed) {
          _pendingSyncCount = count;
          fetchDashboardData();
        }
      });
      syncEngine!.getPendingCount().then((count) {
        if (!_isDisposed) {
          _pendingSyncCount = count;
          notifyListeners();
        }
      });
    }
  }

  void toggleBalanceVisibility() {
    _isBalanceHidden = !_isBalanceHidden;
    notifyListeners();
  }

  Future<void> fetchDashboardData() async {
    _status = WalletHomeStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final balanceFuture = getWalletBalanceUseCase();
    final transactionsFuture = getRecentTransactionsUseCase();

    final results = await Future.wait([balanceFuture, transactionsFuture]);
    if (_isDisposed) return;

    final balanceResult = results[0];
    final transactionsResult = results[1];

    bool hasError = false;
    String? err;

    balanceResult.fold(
      onSuccess: (balance) {
        _walletBalance = balance as WalletBalance;
      },
      onError: (failure) {
        hasError = true;
        err = failure.message;
      },
    );

    transactionsResult.fold(
      onSuccess: (txs) {
        _transactions = txs as List<Transaction>;
      },
      onError: (failure) {
        err ??= failure.message;
      },
    );

    if (hasError && _walletBalance == null) {
      _status = WalletHomeStatus.error;
      _errorMessage = err;
    } else {
      _status = WalletHomeStatus.loaded;
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _syncSubscription?.cancel();
    super.dispose();
  }
}
