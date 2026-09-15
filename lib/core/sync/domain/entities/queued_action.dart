import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum ActionType { sendMoney, contributeSavings, createSavingsGoal }

enum ActionStatus { pending, sending, sent, failed }

class QueuedAction extends Equatable {
  final String id;
  final String idempotencyKey;
  final ActionType actionType;
  final Map<String, dynamic> payload;
  final ActionStatus status;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const QueuedAction({
    required this.id,
    required this.idempotencyKey,
    required this.actionType,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory QueuedAction.create({
    required ActionType actionType,
    required Map<String, dynamic> payload,
    String? id,
    String? idempotencyKey,
  }) {
    const uuid = Uuid();
    return QueuedAction(
      id: id ?? uuid.v4(),
      idempotencyKey: idempotencyKey ?? uuid.v4(),
      actionType: actionType,
      payload: payload,
      status: ActionStatus.pending,
      createdAt: DateTime.now(),
      retryCount: 0,
    );
  }

  QueuedAction copyWith({
    String? id,
    String? idempotencyKey,
    ActionType? actionType,
    Map<String, dynamic>? payload,
    ActionStatus? status,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
  }) {
    return QueuedAction(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      actionType: actionType ?? this.actionType,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idempotency_key': idempotencyKey,
      'action_type': actionType.name,
      'payload': jsonEncode(payload),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory QueuedAction.fromMap(Map<String, dynamic> map) {
    return QueuedAction(
      id: map['id'] as String,
      idempotencyKey: map['idempotency_key'] as String,
      actionType: ActionType.values.firstWhere(
        (e) => e.name == map['action_type'],
        orElse: () => ActionType.sendMoney,
      ),
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      status: ActionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ActionStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    idempotencyKey,
    actionType,
    payload,
    status,
    createdAt,
    retryCount,
    lastError,
  ];
}
