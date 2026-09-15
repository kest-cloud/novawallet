import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
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
}
