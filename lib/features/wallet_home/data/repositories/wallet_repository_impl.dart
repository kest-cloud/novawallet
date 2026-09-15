import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/datasources/wallet_remote_datasource.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  WalletRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Result<WalletBalance>> getWalletBalance() async {
    try {
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
}
