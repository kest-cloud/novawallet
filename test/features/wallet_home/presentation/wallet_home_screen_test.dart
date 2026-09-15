import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/theme/app_theme.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/transaction_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_recent_transactions_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/notifier/wallet_home_provider.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/screens/wallet_home_screen.dart';

/// Fake repository for deterministic UI testing.
class FakeWalletRepository implements WalletRepository {
  WalletBalance balance;
  List<Transaction> transactions;
  int fetchBalanceCallCount = 0;
  int fetchTransactionsCallCount = 0;

  FakeWalletRepository({required this.balance, required this.transactions});

  @override
  Future<Result<WalletBalance>> getWalletBalance() async {
    fetchBalanceCallCount++;
    return Result.success(balance);
  }

  @override
  Future<Result<List<Transaction>>> getRecentTransactions({
    int limit = 20,
  }) async {
    fetchTransactionsCallCount++;
    return Result.success(transactions.take(limit).toList());
  }
}

Widget createTestWidget({
  required WalletHomeProvider provider,
  double textScaleFactor = 1.0,
}) {
  return ChangeNotifierProvider<WalletHomeProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: const WalletHomeScreen(),
      ),
    ),
  );
}

void main() {
  const knownKobo = 125050050; // ₦1,250,500.50
  const testBalance = WalletBalance(
    availableBalance: Money.fromKobo(knownKobo),
    ledgerBalance: Money.fromKobo(knownKobo),
    accountId: 'acc_test_01',
    accountNumber: '0123456789',
    accountName: 'Ademola Afolayan',
  );

  List<Transaction> generateLargeTransactionDataset(int count) {
    final now = DateTime.now();
    return List.generate(count, (index) {
      return TransactionModel(
        id: 'tx_$index',
        title: 'Transaction Item #$index',
        subtitle: 'Sub item #$index',
        amount: Money.fromKobo((index + 1) * 100000), // ₦1,000 * (index+1)
        type: index.isEven ? TransactionType.credit : TransactionType.debit,
        status: TransactionStatus.success,
        timestamp: now.subtract(Duration(hours: index)),
        reference: 'REF_$index',
      );
    });
  }

  group('WalletHomeScreen Widget & Accessibility Tests', () {
    testWidgets(
      '1. Balance renders formatted Naira amount accurately from raw Kobo value (₦1,250,500.50)',
      (WidgetTester tester) async {
        final repo = FakeWalletRepository(
          balance: testBalance,
          transactions: generateLargeTransactionDataset(3),
        );
        final provider = WalletHomeProvider(
          getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
          getRecentTransactionsUseCase: GetRecentTransactionsUseCase(repo),
        );

        await tester.pumpWidget(createTestWidget(provider: provider));
        await tester.pumpAndSettle();

        // Check exact formatted string in widget
        expect(find.text('₦1,250,500.50'), findsOneWidget);
        expect(find.text('Total Available Balance'), findsOneWidget);
        expect(find.text('Acct: 0123456789'), findsOneWidget);
      },
    );

    testWidgets('2. Pull-to-refresh triggers dashboard data reload', (
      WidgetTester tester,
    ) async {
      final repo = FakeWalletRepository(
        balance: testBalance,
        transactions: generateLargeTransactionDataset(5),
      );
      final provider = WalletHomeProvider(
        getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
        getRecentTransactionsUseCase: GetRecentTransactionsUseCase(repo),
      );

      await tester.pumpWidget(createTestWidget(provider: provider));
      await tester.pumpAndSettle();

      // Initial load called balance and transactions once each
      expect(repo.fetchBalanceCallCount, equals(1));
      expect(repo.fetchTransactionsCallCount, equals(1));

      // Trigger pull to refresh gesture
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Assert reloaded
      expect(repo.fetchBalanceCallCount, equals(2));
      expect(repo.fetchTransactionsCallCount, equals(2));
    });

    testWidgets(
      '3. Lazy building verification: Only visible items are built, not the entire dataset at once',
      (WidgetTester tester) async {
        // Create 100 transactions
        final largeDataset = generateLargeTransactionDataset(100);
        final repo = FakeWalletRepository(
          balance: testBalance,
          transactions: largeDataset,
        );
        final provider = WalletHomeProvider(
          getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
          getRecentTransactionsUseCase: GetRecentTransactionsUseCase(repo),
        );

        await tester.pumpWidget(createTestWidget(provider: provider));
        await tester.pumpAndSettle();

        // Item 0 and 1 are near the top and MUST be rendered
        expect(find.byKey(const ValueKey('tx_item_0')), findsOneWidget);
        expect(find.text('Transaction Item #0'), findsOneWidget);

        // Item 95 is far down the list and MUST NOT be built into the widget tree initially
        expect(find.byKey(const ValueKey('tx_item_95')), findsNothing);
        expect(find.text('Transaction Item #95'), findsNothing);

        // Scroll down toward bottom
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();

        // After scrolling, deeper items are built lazily
        expect(find.text('Transaction Item #0'), findsNothing); // Scrolled out
      },
    );

    testWidgets(
      '4. Accessibility & Scale factor: No overflow at 1.0x and 2.0x textScaleFactor',
      (WidgetTester tester) async {
        final semanticsHandle = tester.ensureSemantics();
        final repo = FakeWalletRepository(
          balance: testBalance,
          transactions: generateLargeTransactionDataset(4),
        );

        // --- Test at 1.0x scale ---
        final provider1 = WalletHomeProvider(
          getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
          getRecentTransactionsUseCase: GetRecentTransactionsUseCase(repo),
        );
        await tester.pumpWidget(
          createTestWidget(provider: provider1, textScaleFactor: 1.0),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // --- Test at 2.0x scale (Large accessibility font size) ---
        final provider2 = WalletHomeProvider(
          getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
          getRecentTransactionsUseCase: GetRecentTransactionsUseCase(repo),
        );
        await tester.pumpWidget(
          createTestWidget(provider: provider2, textScaleFactor: 2.0),
        );
        await tester.pumpAndSettle();

        // Confirm zero overflow errors
        expect(tester.takeException(), isNull);

        // Verify key accessibility semantics exist
        expect(
          find.bySemanticsLabel('Send money to bank account'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Open Nova Save savings vault'),
          findsOneWidget,
        );

        semanticsHandle.dispose();
      },
    );
  });
}
