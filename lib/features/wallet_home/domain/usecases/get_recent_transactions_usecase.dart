import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';

class GetRecentTransactionsUseCase {
  final WalletRepository repository;

  const GetRecentTransactionsUseCase(this.repository);

  Future<Result<List<Transaction>>> call({int limit = 20}) {
    return repository.getRecentTransactions(limit: limit);
  }
}
