import 'dart:async';
import 'package:nova_wallet_mobile/core/constants/app_constants.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:synchronized/synchronized.dart';
import 'domain/entities/queued_action.dart';
import 'domain/repositories/sync_queue_repository.dart';

/// Handler signature for executing a queued action over network rails.
typedef ActionHandler = Future<bool> Function(QueuedAction action);

/// Standalone, feature-agnostic offline synchronization engine.
///
/// Ensures exactly-once execution guarantees across app kills, offline queuing,
/// and re-connection replays.
class SyncEngine {
  final SyncQueueRepository repository;
  final NetworkInfo networkInfo;

  final Map<ActionType, ActionHandler> _handlers = {};
  final Lock _lock = Lock();
  StreamSubscription<bool>? _connectivitySubscription;

  SyncEngine({required this.repository, required this.networkInfo});

  /// Initializes the SyncEngine.
  ///
  /// CRITICAL: On startup, any action left in "sending" (e.g. from an app crash
  /// mid-replay) is converted back to "pending" to guarantee exactly-once processing
  /// using its persistent idempotencyKey.
  Future<void> init() async {
    await repository.markSendingAsPending();

    // Listen for connectivity restoration
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((
      isConnected,
    ) {
      if (isConnected) {
        processQueue();
      }
    });

    // If already connected on startup, trigger initial queue processing
    if (await networkInfo.isConnected) {
      unawaited(processQueue());
    }
  }

  /// Registers a feature-specific handler for an [ActionType].
  void registerHandler(ActionType type, ActionHandler handler) {
    _handlers[type] = handler;
  }

  /// Enqueues an action into the SQLite offline queue.
  /// Automatically attempts processing if connectivity is available.
  Future<void> enqueue(QueuedAction action) async {
    await repository.enqueue(action);

    if (await networkInfo.isConnected) {
      unawaited(processQueue());
    }
  }

  /// Processes all pending actions in FIFO order with strict mutual exclusion.
  Future<void> processQueue() async {
    return _lock.synchronized(() async {
      if (!(await networkInfo.isConnected)) return;

      // Retrieve all pending actions FIFO (created_at ASC)
      final pendingActions = await repository.getActionsByStatus([
        ActionStatus.pending,
      ]);

      for (final action in pendingActions) {
        // Re-check connectivity before each action attempt
        if (!(await networkInfo.isConnected)) break;

        final handler = _handlers[action.actionType];
        if (handler == null) continue;

        // 1. Mark action as "sending" BEFORE making the network call
        await repository.updateStatus(action.id, ActionStatus.sending);

        try {
          // 2. Invoke network call with persistent idempotencyKey
          final success = await handler(
            action.copyWith(status: ActionStatus.sending),
          );

          if (success) {
            // 3. Mark "sent" and remove from persistent queue upon verified success
            await repository.delete(action.id);
          } else {
            await _handleActionFailure(action, 'Handler returned false');
          }
        } catch (e) {
          await _handleActionFailure(action, e.toString());
        }
      }
    });
  }

  Future<void> _handleActionFailure(QueuedAction action, String error) async {
    final nextRetry = action.retryCount + 1;
    if (nextRetry >= AppConstants.maxRetryAttempts) {
      await repository.updateStatus(
        action.id,
        ActionStatus.failed,
        error: error,
        retryCount: nextRetry,
      );
    } else {
      // Revert back to pending with incremented retry count for next retry pass
      await repository.updateStatus(
        action.id,
        ActionStatus.pending,
        error: error,
        retryCount: nextRetry,
      );
    }
  }

  /// Reactive stream of all actions in the queue.
  Stream<List<QueuedAction>> get actionsStream => repository.watchActions();

  /// Reactive stream of the pending queue count.
  Stream<int> get pendingCountStream => repository.watchPendingCount();

  /// Gets currently pending actions.
  Future<List<QueuedAction>> getPendingActions() =>
      repository.getActionsByStatus([ActionStatus.pending]);

  /// Gets count of currently pending actions.
  Future<int> getPendingCount() => repository.getPendingCount();

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
