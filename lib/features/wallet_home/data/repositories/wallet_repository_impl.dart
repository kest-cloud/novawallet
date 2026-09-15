import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/transaction_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/datasources/wallet_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final SyncDatabaseHelper? dbHelper;

  WalletRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    this.dbHelper,
  });

  @override
  Future<Result<WalletBalance>> getWalletBalance() async {
    try {
      if (dbHelper != null) {
        final balance = await dbHelper!.getWalletBalance();
        return Result.success(balance);
      }

      if (await networkInfo.isConnected) {
        final balance = await remoteDataSource.fetchWalletBalance();
        return Result.success(balance);
      } else {
        return const Result.error(
          NetworkFailure(
            message: 'No internet connection to fetch wallet balance.',
          ),
        );
      }
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Failed to retrieve balance: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<List<Transaction>>> getRecentTransactions({
    int limit = 20,
  }) async {
    try {
      if (dbHelper != null) {
        final transactions = await dbHelper!.getTransactions(limit: limit);
        return Result.success(transactions);
      }

      if (await networkInfo.isConnected) {
        final transactions = await remoteDataSource.fetchRecentTransactions(
          limit: limit,
        );
        return Result.success(transactions);
      } else {
        return const Result.error(
          NetworkFailure(
            message: 'No internet connection to fetch transactions.',
          ),
        );
      }
    } catch (e) {
      return Result.error(
        ServerFailure(
          message: 'Failed to retrieve transactions: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Result<void>> deductBalance(Money amount) async {
    try {
      if (dbHelper != null) {
        await dbHelper!.deductBalance(amount.kobo);
      }
      return const Result.success(null);
    } catch (e) {
      return Result.error(
        CacheFailure(message: 'Failed to deduct balance: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> recordTransaction(Transaction transaction) async {
    try {
      if (dbHelper != null) {
        final model = TransactionModel(
          id: transaction.id,
          title: transaction.title,
          subtitle: transaction.subtitle,
          amount: transaction.amount,
          type: transaction.type,
          status: transaction.status,
          timestamp: transaction.timestamp,
          reference: transaction.reference,
        );
        await dbHelper!.insertTransaction(model);
      }
      return const Result.success(null);
    } catch (e) {
      return Result.error(
        CacheFailure(message: 'Failed to record transaction: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> updateTransactionStatus(
    String reference,
    TransactionStatus status,
  ) async {
    try {
      if (dbHelper != null) {
        await dbHelper!.updateTransactionStatus(reference, status.name);
      }
      return const Result.success(null);
    } catch (e) {
      return Result.error(
        CacheFailure(
          message: 'Failed to update transaction status: ${e.toString()}',
        ),
      );
    }
  }
}
