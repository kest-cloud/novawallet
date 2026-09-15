import 'package:nova_wallet_mobile/core/error/failures.dart';
import 'package:nova_wallet_mobile/core/error/result.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/datasources/savings_remote_datasource.dart';

class SavingsRepositoryImpl implements SavingsRepository {
  final SavingsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  SavingsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Result<List<SavingsGoal>>> getSavingsGoals() async {
    try {
      if (await networkInfo.isConnected) {
        final goals = await remoteDataSource.fetchSavingsGoals();
        return Result.success(goals);
      } else {
        return const Result.error(
          NetworkFailure(
            message: 'No internet connection to fetch savings goals.',
          ),
        );
      }
    } catch (e) {
      return Result.error(
        ServerFailure(message: 'Failed to load savings goals: ${e.toString()}'),
      );
    }
  }
}
