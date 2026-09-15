import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';

abstract class WalletRepository {
  Future<Result<WalletBalance>> getWalletBalance();
  Future<Result<List<Transaction>>> getRecentTransactions({int limit = 20});
  Future<Result<void>> deductBalance(Money amount);
  Future<Result<void>> recordTransaction(Transaction transaction);
  Future<Result<void>> updateTransactionStatus(
    String reference,
    TransactionStatus status,
  );
}
