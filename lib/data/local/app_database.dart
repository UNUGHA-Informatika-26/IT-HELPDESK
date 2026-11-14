import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static const name = 'helpdesk.db';
  static const version = 1;
  static Database? _instance;

  static Future<Database> open({
    String? databasePath,
    DatabaseFactory? factory,
  }) async {
    final existing = _instance;
    if (existing != null && databasePath == null && factory == null) {
      return existing;
    }
    final selectedFactory = factory ?? databaseFactory;
    final location = databasePath ??
        path.join(await selectedFactory.getDatabasesPath(), name);
    final database = await selectedFactory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    if (databasePath == null && factory == null) _instance = database;
    return database;
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tickets (
        id TEXT PRIMARY KEY,
        uid_pemilik TEXT NOT NULL,
        company_id TEXT NOT NULL,
        ticket_number TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ticket_updates (
        id TEXT PRIMARY KEY,
        ticket_id TEXT NOT NULL,
        from_status TEXT NOT NULL,
        to_status TEXT NOT NULL,
        note TEXT NOT NULL,
        by_name TEXT NOT NULL,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE profile (
        uid TEXT PRIMARY KEY,
        json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE counts (
        uid TEXT NOT NULL,
        key TEXT NOT NULL,
        value INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (uid, key)
      )
    ''');
    await db.execute('''
      CREATE TABLE outbox (
        local_id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        jenis_aksi TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('pending', 'failed')),
        retry_count INTEGER NOT NULL DEFAULT 0,
        pesan_error TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX tickets_uid_created ON tickets(uid_pemilik, created_at)',
    );
    await db.execute(
      'CREATE INDEX outbox_uid_created ON outbox(uid, created_at)',
    );
    await db.execute(
      'CREATE INDEX updates_ticket_created ON ticket_updates(ticket_id, created_at)',
    );
  }

  static Future<void> _upgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) await _create(db, newVersion);
  }
}
