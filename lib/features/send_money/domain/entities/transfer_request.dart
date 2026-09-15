import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

enum TransferExecutionState { completedOnline, queuedOffline }

/// Result returned after submitting a transfer attempt.
class TransferSubmissionResult extends Equatable {
  final String idempotencyKey;
  final String reference;
  final TransferExecutionState executionState;
  final String message;

  const TransferSubmissionResult({
    required this.idempotencyKey,
    required this.reference,
    required this.executionState,
    required this.message,
  });

  bool get isQueuedOffline =>
      executionState == TransferExecutionState.queuedOffline;
  bool get isCompletedOnline =>
      executionState == TransferExecutionState.completedOnline;

  @override
  List<Object?> get props => [
    idempotencyKey,
    reference,
    executionState,
    message,
  ];
}

/// Pure domain entity representing a money transfer request.
/// No Flutter or storage imports.
class TransferRequest extends Equatable {
  final String recipientAccountNumber;
  final String recipientBankCode;
  final String recipientBankName;
  final String recipientName;
  final Money amount;
  final String narration;
  final String idempotencyKey;

  const TransferRequest({
    required this.recipientAccountNumber,
    required this.recipientBankCode,
    this.recipientBankName = 'FirstBank of Nigeria',
    required this.recipientName,
    required this.amount,
    this.narration = '',
    required this.idempotencyKey,
  });

  TransferRequest copyWith({
    String? recipientAccountNumber,
    String? recipientBankCode,
    String? recipientBankName,
    String? recipientName,
    Money? amount,
    String? narration,
    String? idempotencyKey,
  }) {
    return TransferRequest(
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

  @override
  List<Object?> get props => [
    recipientAccountNumber,
    recipientBankCode,
    recipientBankName,
    recipientName,
    amount,
    narration,
    idempotencyKey,
  ];
}
