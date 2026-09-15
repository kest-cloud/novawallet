import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

class TransferRequest extends Equatable {
  final String recipientAccountNumber;
  final String recipientBankCode;
  final String recipientName;
  final Money amount;
  final String narration;
  final String? reference;

  const TransferRequest({
    required this.recipientAccountNumber,
    required this.recipientBankCode,
    required this.recipientName,
    required this.amount,
    this.narration = '',
    this.reference,
  });

  @override
  List<Object?> get props => [
    recipientAccountNumber,
    recipientBankCode,
    recipientName,
    amount,
    narration,
    reference,
  ];
}
