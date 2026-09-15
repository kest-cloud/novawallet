import '../entities/queued_action.dart';

/// Domain contract for persisting and retrieving offline queue actions.
/// No Flutter or specific storage imports.
abstract class SyncQueueRepository {
  Future<void> enqueue(QueuedAction action);

  Future<List<QueuedAction>> getActionsByStatus(List<ActionStatus> statuses);

  Future<List<QueuedAction>> getAllActions();

  Future<void> updateStatus(
    String id,
    ActionStatus status, {
    String? error,
    int? retryCount,
  });

  Future<void> delete(String id);

  Future<void> markSendingAsPending();

  Future<int> getPendingCount();

  Stream<List<QueuedAction>> watchActions();

  Stream<int> watchPendingCount();
}
