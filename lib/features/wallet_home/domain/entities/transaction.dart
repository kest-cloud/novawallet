import 'package:equatable/equatable.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';

enum TransactionType { credit, debit }

enum TransactionStatus { success, pending, failed }

class Transaction extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final Money amount;
  final TransactionType type;
  final TransactionStatus status;
  final DateTime timestamp;
  final String reference;

  const Transaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.reference,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    amount,
    type,
    status,
    timestamp,
    reference,
  ];
}
