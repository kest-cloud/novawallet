import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/wallet_balance.dart';

class WalletBalanceModel extends WalletBalance {
  const WalletBalanceModel({
    required super.availableBalance,
    required super.ledgerBalance,
    required super.accountId,
    required super.accountNumber,
    required super.accountName,
  });

  factory WalletBalanceModel.fromJson(Map<String, dynamic> json) {
    return WalletBalanceModel(
      availableBalance: Money.fromKobo(
        json['available_balance_kobo'] as int? ?? 0,
      ),
      ledgerBalance: Money.fromKobo(json['ledger_balance_kobo'] as int? ?? 0),
      accountId: json['account_id'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'available_balance_kobo': availableBalance.kobo,
    'ledger_balance_kobo': ledgerBalance.kobo,
    'account_id': accountId,
    'account_number': accountNumber,
    'account_name': accountName,
  };
}
