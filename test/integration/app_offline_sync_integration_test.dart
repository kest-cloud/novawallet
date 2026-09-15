import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/sync/domain/repositories/sync_queue_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nova_wallet_mobile/core/di/injection_container.dart' as di;
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/main.dart';

/// Controllable mock network info for full app integration testing.
class TestNetworkInfo implements NetworkInfo {
  bool _connected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  TestNetworkInfo({bool initialConnected = false})
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

/// Mock remote transfer datasource tracking executed idempotency keys.
class RecordingTransferRemoteDataSource implements TransferRemoteDataSource {
  final List<String> submittedKeys = [];
  final Map<String, int> submissionCounts = {};

  @override
  Future<String> submitTransfer(dynamic request) async {
    final key = request.idempotencyKey as String;
    submittedKeys.add(key);
    submissionCounts[key] = (submissionCounts[key] ?? 0) + 1;
    return 'TXN_INT_TEST_$key';
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SyncDatabaseHelper dbHelper;
  late TestNetworkInfo networkInfo;

  setUp(() async {
    // Open a persistent in-memory SQLite database shared across app restarts in this test
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
    await db.execute('''
      CREATE TABLE ${SyncDatabaseHelper.transactionsTable} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        amount_kobo INTEGER NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        reference TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ${SyncDatabaseHelper.walletBalanceTable} (
        account_id TEXT PRIMARY KEY,
        available_balance_kobo INTEGER NOT NULL,
        ledger_balance_kobo INTEGER NOT NULL,
        account_number TEXT NOT NULL,
        account_name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO ${SyncDatabaseHelper.walletBalanceTable} (
        account_id, available_balance_kobo, ledger_balance_kobo, account_number, account_name
      ) VALUES ('acc_nova_001', 125050050, 125050050, '0123456789', 'Ademola Afolayan')
    ''');
    dbHelper = SyncDatabaseHelper(databaseOverride: db);
  });

  tearDown(() async {
    if (di.sl.isRegistered<SyncEngine>()) {
      await di.sl.reset();
    }
    await db.close();
  });

  testWidgets(
    'Top-level App Test: Offline Send Money -> App Restart -> Reconnect -> Exactly-Once Sync',
    (tester) async {
      await tester.runAsync(() async {
        // =====================================================================
        // STEP 1: Boot App in OFFLINE mode
        // =====================================================================
        networkInfo = TestNetworkInfo(initialConnected: false);
        final recordingDataSource = RecordingTransferRemoteDataSource();

        await di.initDependencies(
          networkInfo: networkInfo,
          dbHelper: dbHelper,
          transferRemoteDataSource: recordingDataSource,
        );

        // Render full app
        await tester.pumpWidget(const NovaWalletApp());
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Verify we are on WalletHomeScreen
        expect(find.text('Send Money'), findsWidgets);

        // STEP 2: Navigate to Send Money Screen and Complete 3-Step Flow
        await tester.tap(find.byKey(const Key('action_send_money')));
        await tester.pumpAndSettle();

        // Step 1: Destination Account
        final accountField = find.widgetWithText(
          TextFormField,
          'Account Number',
        );
        expect(accountField, findsOneWidget);
        await tester.enterText(accountField, '0123456789');
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'Account Name');
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'Babatunde Fashola');
        await tester.pumpAndSettle();

        // Tap Next -> Amount Step
        final nextToAmountBtn = find.text('Continue to Amount');
        expect(nextToAmountBtn, findsOneWidget);
        await tester.tap(nextToAmountBtn);
        await tester.pumpAndSettle();

        // Step 2: Amount Input
        final amountField = find.widgetWithText(TextFormField, 'Amount (₦)');
        expect(amountField, findsOneWidget);
        await tester.enterText(amountField, '5000'); // ₦5,000.00
        await tester.pumpAndSettle();

        // Tap Next -> Confirmation Step
        final nextToConfirmBtn = find.text('Review Transfer');
        expect(nextToConfirmBtn, findsOneWidget);
        await tester.tap(nextToConfirmBtn);
        await tester.pumpAndSettle();

        // Step 3: Review & Confirm
        expect(find.text('Confirm Transfer Details'), findsOneWidget);
        final confirmBtn = find.byType(ElevatedButton);
        expect(confirmBtn, findsOneWidget);

        // Execute Confirm while offline
        await tester.tap(confirmBtn);
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // STEP 3: Verify Offline UI Feedback & SQLite Persistence
        expect(
          find.text('Pending — will send when back online'),
          findsWidgets,
        ); // Assert 0 calls were made to backend since offline
        expect(recordingDataSource.submittedKeys.length, 0);

        // Assert 1 action stored in SQLite persistent database
        final repoBeforeRestart = di.sl<SyncQueueRepository>();
        final persistedQueueBeforeRestart = await repoBeforeRestart
            .getAllActions();
        expect(persistedQueueBeforeRestart.length, 1);
        final queuedAction = persistedQueueBeforeRestart.first;
        expect(queuedAction.actionType, ActionType.sendMoney);
        expect(queuedAction.status, ActionStatus.pending);
        final activeIdempotencyKey = queuedAction.idempotencyKey;
        expect(activeIdempotencyKey.isNotEmpty, true);

        // =====================================================================
        // STEP 4: Simulate Full App Termination & Restart
        // =====================================================================
        // Reset DI container to simulate complete process death
        await di.sl.reset();

        // Re-initialize DI as on fresh app cold launch (still offline)
        final recordingDataSourceAfterRestart =
            RecordingTransferRemoteDataSource();
        final networkInfoAfterRestart = TestNetworkInfo(
          initialConnected: false,
        );

        await di.initDependencies(
          networkInfo: networkInfoAfterRestart,
          dbHelper: dbHelper, // same SQLite db instance preserved on disk
          transferRemoteDataSource: recordingDataSourceAfterRestart,
        );

        // Verify persistent queue survived the app crash/restart
        final repoAfterRestart = di.sl<SyncQueueRepository>();
        final persistedQueueAfterRestart = await repoAfterRestart
            .getAllActions();
        expect(persistedQueueAfterRestart.length, 1);
        expect(
          persistedQueueAfterRestart.first.idempotencyKey,
          activeIdempotencyKey,
        );

        // =====================================================================
        // STEP 5: Reconnect to Network -> Verify Exactly-Once Automatic Replay
        // =====================================================================
        networkInfoAfterRestart.setConnected(true);

        // Allow SyncEngine's reconnect listener and replay loop to finish
        await Future.delayed(const Duration(milliseconds: 300));
        await di.sl<SyncEngine>().processQueue();

        // Verify remote backend rail received the transaction
        expect(recordingDataSourceAfterRestart.submittedKeys.length, 1);
        expect(
          recordingDataSourceAfterRestart.submittedKeys.first,
          activeIdempotencyKey,
        );
        expect(
          recordingDataSourceAfterRestart
              .submissionCounts[activeIdempotencyKey],
          1,
        );

        // Assert SQLite queue has removed/completed the action
        final finalQueue = await repoAfterRestart.getAllActions();
        expect(finalQueue.isEmpty, true);

        // Clean up
        networkInfo.dispose();
        networkInfoAfterRestart.dispose();
      });
    },
  );
}
