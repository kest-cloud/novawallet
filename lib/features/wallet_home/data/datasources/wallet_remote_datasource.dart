import 'dart:math';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/transaction_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/wallet_balance_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';

abstract class WalletRemoteDataSource {
  Future<WalletBalanceModel> fetchWalletBalance();
  Future<List<TransactionModel>> fetchRecentTransactions({int limit = 20});
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final Random _random;
  final Duration? fixedLatency;
  final List<TransactionModel>? customTransactions;

  WalletRemoteDataSourceImpl({
    Random? random,
    this.fixedLatency,
    this.customTransactions,
  }) : _random = random ?? Random();

  Future<void> _simulateNetworkLatency() async {
    if (fixedLatency != null) {
      await Future.delayed(fixedLatency!);
      return;
    }
    // 200ms to 800ms simulated network latency
    final delayMs = 200 + _random.nextInt(600);
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  @override
  Future<WalletBalanceModel> fetchWalletBalance() async {
    await _simulateNetworkLatency();
    return const WalletBalanceModel(
      availableBalance: Money.fromKobo(125050050),
      ledgerBalance: Money.fromKobo(125050050),
      accountId: 'acc_nova_001',
      accountNumber: '0123456789',
      accountName: 'Ademola Afolayan',
    );
  }

  @override
  Future<List<TransactionModel>> fetchRecentTransactions({
    int limit = 20,
  }) async {
    await _simulateNetworkLatency();

    if (customTransactions != null) {
      return customTransactions!.take(limit).toList();
    }

    final defaultTransactions = _generateDefaultTransactions();
    return defaultTransactions.take(limit).toList();
  }

  List<TransactionModel> _generateDefaultTransactions() {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 'tx_001',
        title: 'Transfer to Babatunde Raji',
        subtitle: 'GTBank • 0129384756',
        amount: const Money.fromKobo(2500000),
        type: TransactionType.debit,
        status: TransactionStatus.success,
        timestamp: now.subtract(const Duration(minutes: 15)),
        reference: 'TXN_NOV_982347',
      ),
      TransactionModel(
        id: 'tx_002',
        title: 'Salary Deposit - Tech Corp',
        subtitle: 'Direct Inward NIP Transfer',
        amount: const Money.fromKobo(85000000), // ₦850,000.00
        type: TransactionType.credit,
        status: TransactionStatus.success,
        timestamp: now.subtract(const Duration(hours: 4)),
        reference: 'TXN_NIP_192837',
      ),
      TransactionModel(
        id: 'tx_003',
        title: 'NovaSave Vault Contribution',
        subtitle: 'Auto-Debit • Tech Upgrade',
        amount: const Money.fromKobo(5000000), // ₦50,000.00
        type: TransactionType.debit,
        status: TransactionStatus.success,
        timestamp: now.subtract(const Duration(days: 1)),
        reference: 'TXN_NS_001928',
      ),
      TransactionModel(
        id: 'tx_004',
        title: 'Dividend Payout',
        subtitle: 'FirstBank Securities',
        amount: const Money.fromKobo(1250000), // ₦12,500.00
        type: TransactionType.credit,
        status: TransactionStatus.success,
        timestamp: now.subtract(const Duration(days: 2)),
        reference: 'TXN_DIV_776211',
      ),
      TransactionModel(
        id: 'tx_005',
        title: 'Airtime & Data Top-Up',
        subtitle: 'MTN Nigeria VTU',
        amount: const Money.fromKobo(300000), // ₦3,000.00
        type: TransactionType.debit,
        status: TransactionStatus.success,
        timestamp: now.subtract(const Duration(days: 3)),
        reference: 'TXN_VTU_889912',
      ),
    ];
  }
}
