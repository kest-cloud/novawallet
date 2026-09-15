import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';

class TransferRequestModel extends TransferRequest {
  const TransferRequestModel({
    required super.recipientAccountNumber,
    required super.recipientBankCode,
    required super.recipientName,
    required super.amount,
    super.narration = '',
    super.reference,
  });

  factory TransferRequestModel.fromEntity(TransferRequest entity) {
    return TransferRequestModel(
      recipientAccountNumber: entity.recipientAccountNumber,
      recipientBankCode: entity.recipientBankCode,
      recipientName: entity.recipientName,
      amount: entity.amount,
      narration: entity.narration,
      reference: entity.reference,
    );
  }

  factory TransferRequestModel.fromJson(Map<String, dynamic> json) {
    return TransferRequestModel(
      recipientAccountNumber: json['recipient_account_number'] as String? ?? '',
      recipientBankCode: json['recipient_bank_code'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? '',
      amount: Money.fromKobo(json['amount_kobo'] as int? ?? 0),
      narration: json['narration'] as String? ?? '',
      reference: json['reference'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'recipient_account_number': recipientAccountNumber,
    'recipient_bank_code': recipientBankCode,
    'recipient_name': recipientName,
    'amount_kobo': amount.kobo,
    'narration': narration,
    'reference': reference,
  };
}
