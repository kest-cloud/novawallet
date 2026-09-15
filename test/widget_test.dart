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
    await tester.pumpWidget(const NovaWalletApp());
    // Advance timer to complete simulated 300ms remote balance fetch
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('NovaWallet Mobile'), findsOneWidget);
    expect(find.text('Total Available Balance'), findsOneWidget);
    expect(find.text('Send Money'), findsOneWidget);
    expect(find.text('Nova Save'), findsOneWidget);
  });
}
