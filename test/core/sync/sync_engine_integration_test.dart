import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/core/sync/data/repositories/sync_queue_repository_impl.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';

/// Controllable mock for network connectivity.
class FakeNetworkInfo implements NetworkInfo {
  bool _connected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  FakeNetworkInfo({bool initialConnected = false})
    : _connected = initialConnected;

  void setConnected(bool isConnected) {
    _connected = isConnected;
    _controller.add(isConnected);
  }

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

/// Simulated remote financial backend rail recording calls by idempotency key.
class FakeFinancialBackend {
  final List<String> receivedIdempotencyKeys = [];
  final Map<String, int> callCountByIdempotencyKey = {};

  Future<bool> processSendMoney(QueuedAction action) async {
    final key = action.idempotencyKey;
    receivedIdempotencyKeys.add(key);
    callCountByIdempotencyKey[key] = (callCountByIdempotencyKey[key] ?? 0) + 1;
    return true;
  }
}

void main() {
  // Initialize FFI for running SQLite in tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SyncDatabaseHelper dbHelper;
  late SyncQueueRepositoryImpl repository;
  late FakeNetworkInfo fakeNetworkInfo;
  late FakeFinancialBackend fakeBackend;

  setUp(() async {
    // Open a fresh in-memory SQLite database for each test
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE ${SyncDatabaseHelper.tableName} (
        id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        action_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    dbHelper = SyncDatabaseHelper(databaseOverride: db);
    repository = SyncQueueRepositoryImpl(dbHelper: dbHelper);
    fakeNetworkInfo = FakeNetworkInfo(initialConnected: false);
    fakeBackend = FakeFinancialBackend();
  });

  tearDown(() async {
    fakeNetworkInfo.dispose();
    repository.dispose();
    await db.close();
  });

  group('SyncEngine Offline Queue & Exactly-Once Replay Integration Tests', () {
    test(
      'Offline enqueue -> crash mid-replay (stuck in "sending") -> app restart -> reconnect -> exactly-once backend call',
      () async {
        // -------------------------------------------------------------
        // STEP 1: App Instance #1 starts while OFFLINE
        // -------------------------------------------------------------
        fakeNetworkInfo.setConnected(false);

        var syncEngine1 = SyncEngine(
          repository: repository,
          networkInfo: fakeNetworkInfo,
        );
        syncEngine1.registerHandler(
          ActionType.sendMoney,
          fakeBackend.processSendMoney,
        );
        await syncEngine1.init();

        // User submits a ₦5,000 transfer while offline
        final action = QueuedAction.create(
          actionType: ActionType.sendMoney,
          payload: {
            'recipient_account_number': '0123456789',
            'recipient_bank_code': '058',
            'amount_kobo': 500000, // ₦5,000.00
          },
        );

        await syncEngine1.enqueue(action);

        // Verify action is stored in SQLite with status: pending
        final actionsInDb1 = await repository.getAllActions();
        expect(actionsInDb1.length, equals(1));
        expect(actionsInDb1.first.id, equals(action.id));
        expect(
          actionsInDb1.first.idempotencyKey,
          equals(action.idempotencyKey),
        );
        expect(actionsInDb1.first.status, equals(ActionStatus.pending));

        // Assert backend has not received any call yet
        expect(fakeBackend.receivedIdempotencyKeys, isEmpty);

        // -------------------------------------------------------------
        // STEP 2: Simulate app being killed mid-replay while action was in "sending"
        // -------------------------------------------------------------
        // We simulate the action transitioning to "sending" just before sudden process termination
        await repository.updateStatus(action.id, ActionStatus.sending);

        final stuckActions = await repository.getAllActions();
        expect(stuckActions.first.status, equals(ActionStatus.sending));

        // Kill Engine Instance #1
        syncEngine1.dispose();

        // -------------------------------------------------------------
        // STEP 3: App Restart (Instance #2 initialized)
        // -------------------------------------------------------------
        var syncEngine2 = SyncEngine(
          repository: repository,
          networkInfo: fakeNetworkInfo,
        );
        syncEngine2.registerHandler(
          ActionType.sendMoney,
          fakeBackend.processSendMoney,
        );

        // syncEngine2.init() must recover the stuck "sending" action back to "pending"
        await syncEngine2.init();

        final recoveredActions = await repository.getAllActions();
        expect(recoveredActions.length, equals(1));
        expect(recoveredActions.first.status, equals(ActionStatus.pending));
        expect(
          recoveredActions.first.idempotencyKey,
          equals(action.idempotencyKey),
        );

        // Backend still has 0 calls
        expect(fakeBackend.receivedIdempotencyKeys, isEmpty);

        // -------------------------------------------------------------
        // STEP 4: Restore Connectivity -> Exactly-Once Replay
        // -------------------------------------------------------------
        fakeNetworkInfo.setConnected(true);

        // Allow async sync processing to complete
        await syncEngine2.processQueue();

        // -------------------------------------------------------------
        // STEP 5: Verification & Invariants
        // -------------------------------------------------------------
        // 1. Backend received EXACTLY ONE call for this idempotency key
        expect(fakeBackend.receivedIdempotencyKeys.length, equals(1));
        expect(
          fakeBackend.receivedIdempotencyKeys.first,
          equals(action.idempotencyKey),
        );
        expect(
          fakeBackend.callCountByIdempotencyKey[action.idempotencyKey],
          equals(1),
        );

        // 2. Queue is now completely drained and item is removed
        final remainingInDb = await repository.getAllActions();
        expect(remainingInDb, isEmpty);

        final pendingCount = await syncEngine2.getPendingCount();
        expect(pendingCount, equals(0));

        syncEngine2.dispose();
      },
    );

    test(
      'FIFO ordering: Multiple offline actions are processed in exact creation order',
      () async {
        fakeNetworkInfo.setConnected(false);

        final syncEngine = SyncEngine(
          repository: repository,
          networkInfo: fakeNetworkInfo,
        );
        syncEngine.registerHandler(
          ActionType.sendMoney,
          fakeBackend.processSendMoney,
        );
        await syncEngine.init();

        // Enqueue action 1
        final action1 = QueuedAction.create(
          actionType: ActionType.sendMoney,
          payload: {'amount_kobo': 100000},
        );
        await syncEngine.enqueue(action1);
        await Future.delayed(const Duration(milliseconds: 10));

        // Enqueue action 2
        final action2 = QueuedAction.create(
          actionType: ActionType.sendMoney,
          payload: {'amount_kobo': 200000},
        );
        await syncEngine.enqueue(action2);
        await Future.delayed(const Duration(milliseconds: 10));

        // Enqueue action 3
        final action3 = QueuedAction.create(
          actionType: ActionType.sendMoney,
          payload: {'amount_kobo': 300000},
        );
        await syncEngine.enqueue(action3);

        expect(await syncEngine.getPendingCount(), equals(3));

        // Reconnect
        fakeNetworkInfo.setConnected(true);
        await syncEngine.processQueue();

        // Assert FIFO execution order
        expect(
          fakeBackend.receivedIdempotencyKeys,
          equals([
            action1.idempotencyKey,
            action2.idempotencyKey,
            action3.idempotencyKey,
          ]),
        );

        expect(await syncEngine.getPendingCount(), equals(0));
        syncEngine.dispose();
      },
    );
  });
}
