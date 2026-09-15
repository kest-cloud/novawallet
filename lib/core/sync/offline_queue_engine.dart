import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../storage/secure_storage_service.dart';
import '../network/network_info.dart';
import '../constants/app_constants.dart';

enum QueueItemStatus { pending, inProgress, failed, completed }

class QueueItem extends Equatable {
  final String id;
  final String featureKey;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final QueueItemStatus status;
  final String? lastError;

  const QueueItem({
    required this.id,
    required this.featureKey,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = QueueItemStatus.pending,
    this.lastError,
  });

  QueueItem copyWith({
    int? retryCount,
    QueueItemStatus? status,
    String? lastError,
  }) {
    return QueueItem(
      id: id,
      featureKey: featureKey,
      actionType: actionType,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'featureKey': featureKey,
    'actionType': actionType,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'status': status.name,
    'lastError': lastError,
  };

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String,
      featureKey: json['featureKey'] as String,
      actionType: json['actionType'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: QueueItemStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => QueueItemStatus.pending,
      ),
      lastError: json['lastError'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    featureKey,
    actionType,
    payload,
    createdAt,
    retryCount,
    status,
    lastError,
  ];
}

/// Handler signature for processing a queue item.
typedef QueueActionHandler = Future<bool> Function(QueueItem item);

/// Shared Offline Queue Engine contract and implementation.
abstract class OfflineQueueEngine {
  /// Enqueues a new item to be processed.
  Future<void> enqueue(QueueItem item);

  /// Registers a handler for a specific feature key.
  void registerHandler(String featureKey, QueueActionHandler handler);

  /// Triggers processing of all pending items in the queue.
  Future<void> processPendingQueue();

  /// Gets the list of currently pending queue items.
  Future<List<QueueItem>> getPendingItems();

  /// Stream of the count of pending items in the queue.
  Stream<int> get pendingCountStream;

  /// Clears completed or all items from queue.
  Future<void> clearCompleted();
}

class OfflineQueueEngineImpl implements OfflineQueueEngine {
  final SecureStorageService storage;
  final NetworkInfo networkInfo;
  final Map<String, QueueActionHandler> _handlers = {};
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();
  bool _isProcessing = false;

  OfflineQueueEngineImpl({
    required this.storage,
    required this.networkInfo,
  }) {
    // Automatically trigger processing when connection is restored
    networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        processPendingQueue();
      }
    });
  }

  @override
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  @override
  void registerHandler(String featureKey, QueueActionHandler handler) {
    _handlers[featureKey] = handler;
  }

  @override
  Future<void> enqueue(QueueItem item) async {
    final items = await _loadQueue();
    items.add(item);
    await _saveQueue(items);
    _notifyCount(items);

    // Attempt immediate execution if connected
    if (await networkInfo.isConnected) {
      processPendingQueue();
    }
  }

  @override
  Future<List<QueueItem>> getPendingItems() async {
    final items = await _loadQueue();
    return items.where((i) => i.status == QueueItemStatus.pending).toList();
  }

  @override
  Future<void> processPendingQueue() async {
    if (_isProcessing) return;
    if (!(await networkInfo.isConnected)) return;

    _isProcessing = true;
    try {
      final items = await _loadQueue();
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item.status != QueueItemStatus.pending) continue;

        final handler = _handlers[item.featureKey];
        if (handler == null) continue;

        try {
          items[i] = item.copyWith(status: QueueItemStatus.inProgress);
          final success = await handler(item);
          if (success) {
            items[i] = item.copyWith(status: QueueItemStatus.completed);
          } else {
            final nextRetry = item.retryCount + 1;
            items[i] = item.copyWith(
              retryCount: nextRetry,
              status: nextRetry >= AppConstants.maxRetryAttempts
                  ? QueueItemStatus.failed
                  : QueueItemStatus.pending,
              lastError: 'Handler returned false',
            );
          }
        } catch (e) {
          final nextRetry = item.retryCount + 1;
          items[i] = item.copyWith(
            retryCount: nextRetry,
            status: nextRetry >= AppConstants.maxRetryAttempts
                ? QueueItemStatus.failed
                : QueueItemStatus.pending,
            lastError: e.toString(),
          );
        }
      }
      await _saveQueue(items);
      _notifyCount(items);
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Future<void> clearCompleted() async {
    final items = await _loadQueue();
    items.removeWhere((i) => i.status == QueueItemStatus.completed);
    await _saveQueue(items);
    _notifyCount(items);
  }

  Future<List<QueueItem>> _loadQueue() async {
    final raw = await storage.read(AppConstants.offlineQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<QueueItem> items) async {
    final jsonString = jsonEncode(items.map((e) => e.toJson()).toList());
    await storage.write(key: AppConstants.offlineQueueKey, value: jsonString);
  }

  void _notifyCount(List<QueueItem> items) {
    final pending = items
        .where((i) => i.status == QueueItemStatus.pending)
        .length;
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(pending);
    }
  }
}
