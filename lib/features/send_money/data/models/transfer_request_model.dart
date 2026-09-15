import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';

class TransferRequestModel extends TransferRequest {
  const TransferRequestModel({
    required super.recipientAccountNumber,
    required super.recipientBankCode,
    super.recipientBankName = 'FirstBank of Nigeria',
    required super.recipientName,
    required super.amount,
    super.narration = '',
    required super.idempotencyKey,
  });

  factory TransferRequestModel.fromEntity(TransferRequest entity) {
    return TransferRequestModel(
      recipientAccountNumber: entity.recipientAccountNumber,
      recipientBankCode: entity.recipientBankCode,
      recipientBankName: entity.recipientBankName,
      recipientName: entity.recipientName,
      amount: entity.amount,
      narration: entity.narration,
      idempotencyKey: entity.idempotencyKey,
    );
  }

  @override
  TransferRequestModel copyWith({
    String? recipientAccountNumber,
    String? recipientBankCode,
    String? recipientBankName,
    String? recipientName,
    Money? amount,
    String? narration,
    String? idempotencyKey,
  }) {
    return TransferRequestModel(
      recipientAccountNumber:
          recipientAccountNumber ?? this.recipientAccountNumber,
      recipientBankCode: recipientBankCode ?? this.recipientBankCode,
      recipientBankName: recipientBankName ?? this.recipientBankName,
      recipientName: recipientName ?? this.recipientName,
      amount: amount ?? this.amount,
      narration: narration ?? this.narration,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  factory TransferRequestModel.fromJson(Map<String, dynamic> json) {
    return TransferRequestModel(
      recipientAccountNumber: json['recipient_account_number'] as String? ?? '',
      recipientBankCode: json['recipient_bank_code'] as String? ?? '',
      recipientBankName:
          json['recipient_bank_name'] as String? ?? 'FirstBank of Nigeria',
      recipientName: json['recipient_name'] as String? ?? '',
      amount: Money.fromKobo(json['amount_kobo'] as int? ?? 0),
      narration: json['narration'] as String? ?? '',
      idempotencyKey: json['idempotency_key'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'recipient_account_number': recipientAccountNumber,
    'recipient_bank_code': recipientBankCode,
    'recipient_bank_name': recipientBankName,
    'recipient_name': recipientName,
    'amount_kobo': amount.kobo,
    'narration': narration,
    'idempotency_key': idempotencyKey,
  };
}
