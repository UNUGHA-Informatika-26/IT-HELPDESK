import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/core/constants/app_constants.dart';
import 'package:it_helpdesk_flutter/data/local/app_database.dart';
import 'package:it_helpdesk_flutter/data/local/local_cache.dart';
import 'package:it_helpdesk_flutter/data/local/sqlite_local_cache.dart';
import 'package:it_helpdesk_flutter/models/ticket.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late SqliteLocalCache cache;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await AppDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    cache = SqliteLocalCache(openDatabase: () async => database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads tickets, replacing an existing ticket by ID', () async {
    final ticket = _ticket(title: 'Pertama');
    await cache.saveTicket('user-1', ticket);
    await cache.saveTicket('user-1', _ticket(title: 'Diperbarui'));

    final result = await cache.getTickets('user-1');

    expect(result, hasLength(1));
    expect(result.single.title, 'Diperbarui');
  });

  test('deletes only the selected uid data and outbox', () async {
    await cache.saveTicket('user-1', _ticket());
    await cache.saveTicket('user-2', _ticket(id: 'ticket-2'));
    await cache.enqueue(
      OutboxItem(
        localId: 'local-1',
        uid: 'user-1',
        action: OutboxActionType.create,
        ticketId: 'ticket-1',
        payload: const {},
        createdAt: DateTime.utc(2026),
      ),
    );

    await cache.clearUser('user-1');

    expect(await cache.getTickets('user-1'), isEmpty);
    expect(await cache.getOutbox('user-1'), isEmpty);
    expect((await cache.getTickets('user-2')).single.id, 'ticket-2');
  });
}

Ticket _ticket({String id = 'ticket-1', String title = 'Tiket'}) => Ticket(
      id: id,
      ticketNumber: 'HD-TICKET',
      title: title,
      description: 'Deskripsi',
      category: 'Printer',
      priority: 'Biasa',
      status: TicketStatuses.waiting,
      userId: 'user-1',
      userName: 'Pengguna',
      companyId: 'company-1',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
