import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/transaction_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/wallet_balance_model.dart';

class SyncDatabaseHelper {
  static const String tableName = 'queued_actions';
  static const String transactionsTable = 'transactions';
  static const String walletBalanceTable = 'wallet_balance';
  static const String dbFileName = 'novawallet_sync_queue.db';
  static const int dbVersion = 1;

  Database? _db;

  SyncDatabaseHelper({Database? databaseOverride}) : _db = databaseOverride;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, dbFileName);

    return await openDatabase(path, version: dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Queued Actions Table for offline-sync
    await db.execute('''
      CREATE TABLE $tableName (
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
      CREATE INDEX idx_status_created_at ON $tableName (status, created_at ASC)
    ''');

    // 2. Persistent Transactions Table
    await db.execute('''
      CREATE TABLE $transactionsTable (
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
      CREATE INDEX idx_tx_timestamp ON $transactionsTable (timestamp DESC)
    ''');

    // 3. Persistent Wallet Balance Table
    await db.execute('''
      CREATE TABLE $walletBalanceTable (
        account_id TEXT PRIMARY KEY,
        available_balance_kobo INTEGER NOT NULL,
        ledger_balance_kobo INTEGER NOT NULL,
        account_number TEXT NOT NULL,
        account_name TEXT NOT NULL
      )
    ''');

    // Seed initial starting balance on fresh install (₦1,250,500.50) with 0 transactions
    await db.execute('''
      INSERT OR IGNORE INTO $walletBalanceTable (
        account_id,
        available_balance_kobo,
        ledger_balance_kobo,
        account_number,
        account_name
      ) VALUES (
        'acc_nova_001',
        125050050,
        125050050,
        '0123456789',
        'Ademola Afolayan'
      )
    ''');
  }

  // -------------------------------------------------------------
  // Wallet Balance Operations
  // -------------------------------------------------------------
  Future<WalletBalanceModel> getWalletBalance() async {
    final db = await database;
    final results = await db.query(walletBalanceTable, limit: 1);
    if (results.isEmpty) {
      const initialModel = WalletBalanceModel(
        availableBalance: Money.fromKobo(125050050),
        ledgerBalance: Money.fromKobo(125050050),
        accountId: 'acc_nova_001',
        accountNumber: '0123456789',
        accountName: 'Ademola Afolayan',
      );
      await db.insert(walletBalanceTable, {
        'account_id': initialModel.accountId,
        'available_balance_kobo': initialModel.availableBalance.kobo,
        'ledger_balance_kobo': initialModel.ledgerBalance.kobo,
        'account_number': initialModel.accountNumber,
        'account_name': initialModel.accountName,
      });
      return initialModel;
    }

    final row = results.first;
    return WalletBalanceModel(
      availableBalance: Money.fromKobo(row['available_balance_kobo'] as int),
      ledgerBalance: Money.fromKobo(row['ledger_balance_kobo'] as int),
      accountId: row['account_id'] as String,
      accountNumber: row['account_number'] as String,
      accountName: row['account_name'] as String,
    );
  }

  Future<void> deductBalance(int amountKobo) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $walletBalanceTable 
      SET available_balance_kobo = available_balance_kobo - ?,
          ledger_balance_kobo = ledger_balance_kobo - ?
      WHERE account_id = 'acc_nova_001'
    ''',
      [amountKobo, amountKobo],
    );
  }

  // -------------------------------------------------------------
  // Transactions Operations
  // -------------------------------------------------------------
  Future<List<TransactionModel>> getTransactions({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      transactionsTable,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((row) => TransactionModel.fromJson(row)).toList();
  }

  Future<void> insertTransaction(TransactionModel tx) async {
    final db = await database;
    await db.insert(
      transactionsTable,
      tx.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransactionStatus(String reference, String status) async {
    final db = await database;
    await db.update(
      transactionsTable,
      {'status': status},
      where: 'reference = ?',
      whereArgs: [reference],
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
