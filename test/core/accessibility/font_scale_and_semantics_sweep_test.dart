import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/domain/repositories/sync_queue_repository.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/core/theme/app_theme.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/datasources/savings_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/models/savings_goal_model.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/repositories/savings_repository_impl.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/contribute_to_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/create_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/get_savings_goals_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/notifier/nova_save_provider.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/screens/nova_save_screen.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';
import 'package:nova_wallet_mobile/features/send_money/data/repositories/transfer_repository_impl.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/usecases/send_money_usecase.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/notifier/send_money_provider.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/screens/send_money_screen.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/transaction_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_recent_transactions_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/notifier/wallet_home_provider.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/screens/wallet_home_screen.dart';
import 'package:provider/provider.dart';

class FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class FakeSyncQueueRepository implements SyncQueueRepository {
  @override
  Future<void> enqueue(QueuedAction action) async {}
  @override
  Future<List<QueuedAction>> getAllActions() async => [];
  @override
  Future<List<QueuedAction>> getActionsByStatus(List<ActionStatus> s) async =>
      [];
  @override
  Future<void> updateStatus(
    String id,
    ActionStatus s, {
    String? error,
    int? retryCount,
  }) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> markSendingAsPending() async {}
  @override
  Future<int> getPendingCount() async => 0;
  @override
  Stream<List<QueuedAction>> watchActions() => const Stream.empty();
  @override
  Stream<int> watchPendingCount() => Stream.value(0);
}

class FakeWalletRepository implements WalletRepository {
  @override
  Future<Result<WalletBalance>> getWalletBalance() async {
    return const Result.success(
      WalletBalance(
        availableBalance: Money.fromKobo(150000000),
        ledgerBalance: Money.fromKobo(150000000),
        accountId: 'acc_01',
        accountNumber: '0123456789',
        accountName: 'Oluwaseun Bakare',
      ),
    );
  }

  @override
  Future<Result<List<Transaction>>> getRecentTransactions({
    int limit = 20,
  }) async {
    return Result.success([
      TransactionModel(
        id: 'tx_01',
        title: 'Transfer to Chioma',
        amount: const Money.fromKobo(2500000),
        type: TransactionType.debit,
        status: TransactionStatus.success,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        subtitle: '',
        reference: '',
      ),
    ]);
  }

  @override
  Future<Result<void>> deductBalance(Money amount) async =>
      const Result.success(null);

  @override
  Future<Result<void>> recordTransaction(Transaction transaction) async =>
      const Result.success(null);

  @override
  Future<Result<void>> updateTransactionStatus(
    String reference,
    TransactionStatus status,
  ) async => const Result.success(null);
}

class FakeTransferRemoteDataSource implements TransferRemoteDataSource {
  @override
  Future<String> submitTransfer(TransferRequestModel request) async =>
      'REF_123';
}

class FakeSavingsRemoteDataSource implements SavingsRemoteDataSource {
  @override
  Future<List<SavingsGoalModel>> fetchSavingsGoals() async {
    return [
      SavingsGoalModel(
        id: 'goal_01',
        title: 'Tech Upgrade Vault',
        targetAmount: const Money.fromKobo(50000000),
        currentAmount: const Money.fromKobo(25000000),
        targetDate: DateTime.now().add(const Duration(days: 90)),
        isLocked: false,
      ),
    ];
  }

  @override
  Future<SavingsGoalModel> createGoal(Map<String, dynamic> payload) async =>
      SavingsGoalModel.fromJson(payload);

  @override
  Future<SavingsGoalModel> contributeToGoal(
    Map<String, dynamic> payload,
  ) async => SavingsGoalModel.fromJson(payload);
}

void main() {
  late FakeNetworkInfo networkInfo;
  late FakeSyncQueueRepository syncQueueRepository;
  late SyncEngine syncEngine;

  setUp(() {
    networkInfo = FakeNetworkInfo();
    syncQueueRepository = FakeSyncQueueRepository();
    syncEngine = SyncEngine(
      repository: syncQueueRepository,
      networkInfo: networkInfo,
    );
  });

  group('Accessibility Semantics & Font Scaling Sweep (1.0x, 1.3x, 2.0x)', () {
    testWidgets(
      '1. WalletHomeScreen renders without overflow at 1.0x, 1.3x, and 2.0x scale and passes Semantics audit',
      (WidgetTester tester) async {
        final walletRepo = FakeWalletRepository();
        final provider = WalletHomeProvider(
          getWalletBalanceUseCase: GetWalletBalanceUseCase(walletRepo),
          getRecentTransactionsUseCase: GetRecentTransactionsUseCase(
            walletRepo,
          ),
          syncEngine: syncEngine,
        );

        for (final scale in [1.0, 1.3, 2.0]) {
          await tester.pumpWidget(
            ChangeNotifierProvider<WalletHomeProvider>.value(
              value: provider,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(400, 850),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const WalletHomeScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert elements are visible and no overflow errors occurred
          expect(find.text('NovaWallet Mobile'), findsOneWidget);
          expect(find.text('Total Available Balance'), findsOneWidget);
          expect(find.text('Send Money'), findsOneWidget);
          expect(find.text('Nova Save'), findsOneWidget);

          // Verify Semantics labels exist
          expect(
            find.bySemanticsLabel('Send money to bank account'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Open Nova Save savings vault'),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel('View notifications'), findsOneWidget);
        }
      },
    );

    testWidgets(
      '2. SendMoneyScreen renders without overflow at 1.0x, 1.3x, and 2.0x scale and passes Semantics audit',
      (WidgetTester tester) async {
        final transferRepo = TransferRepositoryImpl(
          remoteDataSource: FakeTransferRemoteDataSource(),
          networkInfo: networkInfo,
          syncEngine: syncEngine,
        );
        final provider = SendMoneyProvider(
          sendMoneyUseCase: SendMoneyUseCase(transferRepo),
        );

        for (final scale in [1.0, 1.3, 2.0]) {
          await tester.pumpWidget(
            ChangeNotifierProvider<SendMoneyProvider>.value(
              value: provider,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(400, 850),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const SendMoneyScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Step 1 check
          expect(find.text('Who are you sending to?'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Continue to enter transfer amount'),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      '3. NovaSaveScreen renders without overflow at 1.0x, 1.3x, and 2.0x scale and passes Semantics audit',
      (WidgetTester tester) async {
        final savingsRepo = SavingsRepositoryImpl(
          remoteDataSource: FakeSavingsRemoteDataSource(),
          networkInfo: networkInfo,
          syncEngine: syncEngine,
        );
        final provider = NovaSaveProvider(
          getSavingsGoalsUseCase: GetSavingsGoalsUseCase(savingsRepo),
          createSavingsGoalUseCase: CreateSavingsGoalUseCase(savingsRepo),
          contributeToSavingsGoalUseCase: ContributeToSavingsGoalUseCase(
            savingsRepo,
          ),
        );

        for (final scale in [1.0, 1.3, 2.0]) {
          await tester.pumpWidget(
            ChangeNotifierProvider<NovaSaveProvider>.value(
              value: provider,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(400, 850),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const NovaSaveScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Nova Save'), findsOneWidget);
          expect(find.text('Total Locked & Active Savings'), findsOneWidget);
          expect(find.text('Tech Upgrade Vault'), findsOneWidget);

          // Verify Semantics for progress and action buttons
          expect(
            find.bySemanticsLabel(
              'Savings progress for Tech Upgrade Vault: 50 percent',
            ),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Contribute funds to Tech Upgrade Vault'),
            findsOneWidget,
          );
        }
      },
    );
  });
}
