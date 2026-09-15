import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/wallet_balance_model.dart';

abstract class WalletRemoteDataSource {
  Future<WalletBalanceModel> fetchWalletBalance();
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  @override
  Future<WalletBalanceModel> fetchWalletBalance() async {
    // Simulated remote API response
    await Future.delayed(const Duration(milliseconds: 300));
    return const WalletBalanceModel(
      availableBalance: Money.fromKobo(125050000),
      ledgerBalance: Money.fromKobo(125050000),
      accountId: 'acc_nova_001',
      accountNumber: '0123456789',
      accountName: 'Ademola Afolayan',
    );
  }
}
