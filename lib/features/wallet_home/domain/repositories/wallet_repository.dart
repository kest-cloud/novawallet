import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';

abstract class WalletRepository {
  Future<Result<WalletBalance>> getWalletBalance();
  Future<Result<List<Transaction>>> getRecentTransactions({int limit = 20});
}
