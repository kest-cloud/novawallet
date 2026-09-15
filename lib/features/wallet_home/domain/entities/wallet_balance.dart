import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

class WalletBalance extends Equatable {
  final Money availableBalance;
  final Money ledgerBalance;
  final String accountId;
  final String accountNumber;
  final String accountName;

  const WalletBalance({
    required this.availableBalance,
    required this.ledgerBalance,
    required this.accountId,
    required this.accountNumber,
    required this.accountName,
  });

  @override
  List<Object?> get props => [
    availableBalance,
    ledgerBalance,
    accountId,
    accountNumber,
    accountName,
  ];
}
