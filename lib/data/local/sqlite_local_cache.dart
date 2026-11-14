import 'package:sqflite/sqflite.dart';

import '../../models/app_user.dart';
import '../../models/ticket.dart';
import '../../models/ticket_update.dart';
import 'app_database.dart';
import 'local_cache.dart';
import 'local_model_mapper.dart';

class SqliteLocalCache implements LocalCache {
  SqliteLocalCache({Future<Database> Function()? openDatabase})
      : _openDatabase = openDatabase ?? AppDatabase.open;

  final Future<Database> Function() _openDatabase;

  @override
  Future<List<Ticket>> getTickets(String uid) async {
    final db = await _openDatabase();
    final rows = await db.query(
      'tickets',
      where: 'uid_pemilik = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
    );
    final outbox = await getOutbox(uid);
    final byTicketId = <String, OutboxItem>{
      for (final item in outbox) item.ticketId: item,
    };
    return rows
        .map((row) => LocalModelMapper.ticketFromRow(
              row,
              outbox: byTicketId[row['id']],
            ))
        .toList();
  }

  @override
  Future<void> saveTickets(String uid, List<Ticket> tickets) async {
    final db = await _openDatabase();
    await db.transaction((transaction) async {
      for (final ticket in tickets) {
        await transaction.insert(
          'tickets',
          LocalModelMapper.ticketToRow(uid, ticket),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> saveTicket(String uid, Ticket ticket) async {
    final db = await _openDatabase();
    await db.insert(
      'tickets',
      LocalModelMapper.ticketToRow(uid, ticket),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeTicket(String uid, String ticketId) async {
    final db = await _openDatabase();
    await db.delete(
      'tickets',
      where: 'id = ? AND uid_pemilik = ?',
      whereArgs: [ticketId, uid],
    );
    await db.delete(
      'ticket_updates',
      where: 'ticket_id = ?',
      whereArgs: [ticketId],
    );
  }

  @override
  Future<List<TicketUpdate>> getUpdates(String ticketId) async {
    final db = await _openDatabase();
    final rows = await db.query(
      'ticket_updates',
      where: 'ticket_id = ?',
      whereArgs: [ticketId],
      orderBy: 'created_at DESC',
    );
    return rows.map(LocalModelMapper.updateFromRow).toList();
  }

  @override
  Future<void> saveUpdates(String ticketId, List<TicketUpdate> updates) async {
    final db = await _openDatabase();
    await db.transaction((transaction) async {
      for (final update in updates) {
        await transaction.insert(
          'ticket_updates',
          LocalModelMapper.updateToRow(ticketId, update),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> saveProfile(AppUser user) async {
    final db = await _openDatabase();
    await db.insert(
      'profile',
      {'uid': user.uid, 'json': LocalModelMapper.profileToJson(user)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<AppUser?> getProfile(String uid) async {
    final db = await _openDatabase();
    final rows = await db.query('profile', where: 'uid = ?', whereArgs: [uid]);
    if (rows.isEmpty) return null;
    return LocalModelMapper.profileFromJson(uid, rows.first['json']! as String);
  }

  @override
  Future<void> saveCounts(String uid, Map<String, int> counts) async {
    final db = await _openDatabase();
    final now = DateTime.now().toIso8601String();
    await db.transaction((transaction) async {
      for (final entry in counts.entries) {
        await transaction.insert(
          'counts',
          {
            'uid': uid,
            'key': entry.key,
            'value': entry.value,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<Map<String, int>?> getCounts(String uid) async {
    final db = await _openDatabase();
    final rows = await db.query('counts', where: 'uid = ?', whereArgs: [uid]);
    if (rows.isEmpty) return null;
    return {
      for (final row in rows) row['key']! as String: row['value']! as int
    };
  }

  @override
  Future<DateTime?> getLastUpdated(String uid) async {
    final db = await _openDatabase();
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS updated_at FROM tickets WHERE uid_pemilik = ?',
      [uid],
    );
    final value = rows.first['updated_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  @override
  Future<void> enqueue(OutboxItem item) async {
    final db = await _openDatabase();
    await db.insert(
      'outbox',
      LocalModelMapper.outboxToRow(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<OutboxItem>> getOutbox(String uid) async {
    final db = await _openDatabase();
    final rows = await db.query(
      'outbox',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'created_at ASC, local_id ASC',
    );
    return rows.map(LocalModelMapper.outboxFromRow).toList();
  }

  @override
  Future<void> updateOutbox(OutboxItem item) async {
    final db = await _openDatabase();
    await db.update(
      'outbox',
      LocalModelMapper.outboxToRow(item),
      where: 'local_id = ? AND uid = ?',
      whereArgs: [item.localId, item.uid],
    );
  }

  @override
  Future<void> removeOutbox(String localId) async {
    final db = await _openDatabase();
    await db.delete('outbox', where: 'local_id = ?', whereArgs: [localId]);
  }

  @override
  Future<void> clearUser(String uid) async {
    final db = await _openDatabase();
    await db.transaction((transaction) async {
      final tickets = await transaction.query(
        'tickets',
        columns: ['id'],
        where: 'uid_pemilik = ?',
        whereArgs: [uid],
      );
      for (final ticket in tickets) {
        await transaction.delete(
          'ticket_updates',
          where: 'ticket_id = ?',
          whereArgs: [ticket['id']],
        );
      }
      await transaction.delete(
        'tickets',
        where: 'uid_pemilik = ?',
        whereArgs: [uid],
      );
      await transaction.delete('profile', where: 'uid = ?', whereArgs: [uid]);
      await transaction.delete('counts', where: 'uid = ?', whereArgs: [uid]);
      await transaction.delete('outbox', where: 'uid = ?', whereArgs: [uid]);
    });
  }
}
