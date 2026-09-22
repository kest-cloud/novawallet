import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/constants/app_constants.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:synchronized/synchronized.dart';
import 'domain/entities/queued_action.dart';
import 'domain/entities/sync_progress.dart';
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
  final Duration syncStepDelay;

  final Map<ActionType, ActionHandler> _handlers = {};
  final Lock _lock = Lock();
  StreamSubscription<bool>? _connectivitySubscription;
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();
  SyncProgress _currentProgress = SyncProgress.idle;

  SyncEngine({
    required this.repository,
    required this.networkInfo,
    this.syncStepDelay = const Duration(milliseconds: 1800),
  });

  /// Current synchronization progress state.
  SyncProgress get currentProgress => _currentProgress;

  /// Reactive stream of sync progress for UI progress bars.
  Stream<SyncProgress> get progressStream => _progressController.stream;

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
        debugPrint(
          '[SyncEngine] Connectivity restored event received -> triggering processQueue()',
        );
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
    debugPrint(
      '[SyncEngine] Enqueuing offline action [${action.actionType.name}] id: ${action.id} with persistent idempotencyKey: ${action.idempotencyKey}',
    );
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

      if (pendingActions.isEmpty) {
        _updateProgress(SyncProgress.idle);
        return;
      }

      debugPrint(
        '[SyncEngine] Connection ACTIVE. Processing ${pendingActions.length} queued action(s)...',
      );

      final total = pendingActions.length;
      _updateProgress(
        SyncProgress(
          isSyncing: true,
          totalCount: total,
          currentItemIndex: 1,
          progress: 0.0,
          currentActionDescription: _describeAction(pendingActions.first),
        ),
      );

      for (int i = 0; i < pendingActions.length; i++) {
        final action = pendingActions[i];
        // Re-check connectivity before each action attempt
        if (!(await networkInfo.isConnected)) {
          debugPrint(
            '[SyncEngine] Connection lost during queue processing. Halting replay.',
          );
          break;
        }

        final handler = _handlers[action.actionType];
        if (handler == null) {
          debugPrint(
            '[SyncEngine] No handler registered for ${action.actionType.name}, skipping action ${action.id}',
          );
          continue;
        }

        debugPrint(
          '[SyncEngine] Activating/Replaying action ${action.id} (${action.actionType.name}) with persistent idempotencyKey: ${action.idempotencyKey}',
        );

        _updateProgress(
          SyncProgress(
            isSyncing: true,
            totalCount: total,
            currentItemIndex: i + 1,
            progress: (i) / total,
            currentActionDescription: _describeAction(action),
          ),
        );

        // 1. Mark action as "sending" BEFORE making the network call
        await repository.updateStatus(action.id, ActionStatus.sending);

        // Simulated non-blocking delay so user visibly sees queue item retry in progress
        if (syncStepDelay > Duration.zero) {
          await Future.delayed(syncStepDelay);
        }

        try {
          // 2. Invoke network call with persistent idempotencyKey
          final success = await handler(
            action.copyWith(status: ActionStatus.sending),
          );

          if (success) {
            // 3. Mark "sent" and remove from persistent queue upon verified success
            debugPrint(
              '[SyncEngine] Successfully synced action ${action.id} with idempotencyKey: ${action.idempotencyKey}',
            );
            await repository.delete(action.id);
          } else {
            debugPrint(
              '[SyncEngine] Handler returned false for action ${action.id} with idempotencyKey: ${action.idempotencyKey}',
            );
            await _handleActionFailure(action, 'Handler returned false');
          }
        } catch (e) {
          debugPrint(
            '[SyncEngine] Exception syncing action ${action.id} with idempotencyKey: ${action.idempotencyKey}: $e',
          );
          await _handleActionFailure(action, e.toString());
        }

        _updateProgress(
          SyncProgress(
            isSyncing: true,
            totalCount: total,
            currentItemIndex: i + 1,
            progress: (i + 1) / total,
            currentActionDescription: _describeAction(action),
          ),
        );
      }

      if (syncStepDelay > Duration.zero) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _updateProgress(SyncProgress.idle);
    });
  }

  void _updateProgress(SyncProgress progress) {
    _currentProgress = progress;
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  String _describeAction(QueuedAction action) {
    switch (action.actionType) {
      case ActionType.sendMoney:
        final recipient =
            action.payload['recipient_name'] as String? ??
            action.payload['recipient_account_number'] as String? ??
            '';
        final kobo = action.payload['amount_kobo'] as int? ?? 0;
        final amountStr = Money.fromKobo(kobo).formatToNaira();
        return recipient.isNotEmpty
            ? 'Sending $amountStr to $recipient'
            : 'Sending $amountStr';
      case ActionType.contributeSavings:
        final kobo = action.payload['amount_kobo'] as int? ?? 0;
        final amountStr = Money.fromKobo(kobo).formatToNaira();
        return 'Depositing $amountStr to NovaSave Vault';
      case ActionType.createSavingsGoal:
        final title =
            action.payload['title'] as String? ?? 'NovaSave Target Vault';
        return 'Creating vault "$title"';
    }
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
    _progressController.close();
  }
}
