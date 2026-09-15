import '../../../../core/error/result.dart';
import '../entities/wallet_balance.dart';
import '../repositories/wallet_repository.dart';

class GetWalletBalanceUseCase {
  final WalletRepository repository;

  const GetWalletBalanceUseCase(this.repository);

  Future<Result<WalletBalance>> call() {
    return repository.getWalletBalance();
  }
}
