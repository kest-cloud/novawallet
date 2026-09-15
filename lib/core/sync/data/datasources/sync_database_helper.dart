import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SyncDatabaseHelper {
  static const String tableName = 'queued_actions';
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

    // Index for high-performance FIFO queries filtered by status
    await db.execute('''
      CREATE INDEX idx_status_created_at ON $tableName (status, created_at ASC)
    ''');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
