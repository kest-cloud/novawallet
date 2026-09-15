import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nova_wallet_mobile/core/di/injection_container.dart' as di;
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/main.dart';

class TestNetworkInfo implements NetworkInfo {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void dispose() => _controller.close();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final inMemoryDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    await inMemoryDb.execute('''
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
    await inMemoryDb.execute('''
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
    await inMemoryDb.execute('''
      CREATE TABLE ${SyncDatabaseHelper.walletBalanceTable} (
        account_id TEXT PRIMARY KEY,
        available_balance_kobo INTEGER NOT NULL,
        ledger_balance_kobo INTEGER NOT NULL,
        account_number TEXT NOT NULL,
        account_name TEXT NOT NULL
      )
    ''');
    await inMemoryDb.execute('''
      INSERT INTO ${SyncDatabaseHelper.walletBalanceTable} (
        account_id, available_balance_kobo, ledger_balance_kobo, account_number, account_name
      ) VALUES ('acc_nova_001', 125050050, 125050050, '0123456789', 'Ademola Afolayan')
    ''');

    await di.initDependencies(
      networkInfo: TestNetworkInfo(),
      dbHelper: SyncDatabaseHelper(databaseOverride: inMemoryDb),
    );
  });

  tearDown(() async {
    await di.sl.reset();
  });

  testWidgets('NovaWalletApp smoke test - renders wallet home screen', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const NovaWalletApp());
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('NovaWallet Mobile'), findsOneWidget);
      expect(find.text('Total Available Balance'), findsOneWidget);
      expect(find.text('Send Money'), findsOneWidget);
      expect(find.text('Nova Save'), findsOneWidget);
    });
  });
}
