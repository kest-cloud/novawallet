import 'dart:async';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/domain/repositories/sync_queue_repository.dart';
import 'package:sqflite/sqflite.dart';

class SyncQueueRepositoryImpl implements SyncQueueRepository {
  final SyncDatabaseHelper dbHelper;
  final StreamController<List<QueuedAction>> _actionsController =
      StreamController<List<QueuedAction>>.broadcast();
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  SyncQueueRepositoryImpl({required this.dbHelper});

  Future<Database> get _db => dbHelper.database;

  @override
  Future<void> enqueue(QueuedAction action) async {
    final db = await _db;
    await db.insert(
      SyncDatabaseHelper.tableName,
      action.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyListeners();
  }

  @override
  Future<List<QueuedAction>> getActionsByStatus(
    List<ActionStatus> statuses,
  ) async {
    final db = await _db;
    if (statuses.isEmpty) return [];

    final placeholders = List.filled(statuses.length, '?').join(', ');
    final statusNames = statuses.map((s) => s.name).toList();

    final List<Map<String, dynamic>> maps = await db.query(
      SyncDatabaseHelper.tableName,
      where: 'status IN ($placeholders)',
      whereArgs: statusNames,
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => QueuedAction.fromMap(map)).toList();
  }

  @override
  Future<List<QueuedAction>> getAllActions() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      SyncDatabaseHelper.tableName,
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => QueuedAction.fromMap(map)).toList();
  }

  @override
  Future<void> updateStatus(
    String id,
    ActionStatus status, {
    String? error,
    int? retryCount,
  }) async {
    final db = await _db;
    final values = <String, dynamic>{'status': status.name};
    if (error != null) {
      values['last_error'] = error;
    }
    if (retryCount != null) {
      values['retry_count'] = retryCount;
    }

    await db.update(
      SyncDatabaseHelper.tableName,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(
      SyncDatabaseHelper.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notifyListeners();
  }

  @override
  Future<void> markSendingAsPending() async {
    final db = await _db;
    await db.update(
      SyncDatabaseHelper.tableName,
      {'status': ActionStatus.pending.name},
      where: 'status = ?',
      whereArgs: [ActionStatus.sending.name],
    );
    await _notifyListeners();
  }

  @override
  Future<int> getPendingCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${SyncDatabaseHelper.tableName} WHERE status = ?',
      [ActionStatus.pending.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Stream<List<QueuedAction>> watchActions() => _actionsController.stream;

  @override
  Stream<int> watchPendingCount() => _pendingCountController.stream;

  Future<void> _notifyListeners() async {
    if (!_actionsController.isClosed) {
      final all = await getAllActions();
      _actionsController.add(all);
    }
    if (!_pendingCountController.isClosed) {
      final count = await getPendingCount();
      _pendingCountController.add(count);
    }
  }

  void dispose() {
    _actionsController.close();
    _pendingCountController.close();
  }
}
