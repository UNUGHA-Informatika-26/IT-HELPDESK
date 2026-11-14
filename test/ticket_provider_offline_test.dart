import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/core/constants/app_constants.dart';
import 'package:it_helpdesk_flutter/data/local/app_database.dart';
import 'package:it_helpdesk_flutter/data/local/local_cache.dart';
import 'package:it_helpdesk_flutter/data/local/sqlite_local_cache.dart';
import 'package:it_helpdesk_flutter/features/connectivity/connectivity_cubit.dart';
import 'package:it_helpdesk_flutter/models/app_user.dart';
import 'package:it_helpdesk_flutter/models/ticket.dart';
import 'package:it_helpdesk_flutter/providers/ticket_provider.dart';
import 'package:it_helpdesk_flutter/services/ticket_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _FakeTicketService extends TicketService {
  _FakeTicketService() : super(firestore: _MockFirestore());

  int _id = 0;
  final List<String> sentIds = [];
  final List<String> sentActions = [];
  FirebaseException? createError;
  FirebaseException? editError;
  FirebaseException? cancelError;
  Ticket? serverTicket;
  Completer<void>? createGate;

  @override
  String newTicketId() => 'ticket-${++_id}';

  @override
  Future<String> createTicket({
    required AppUser user,
    required String title,
    required String description,
    required String category,
    required String priority,
    String? ticketId,
  }) async {
    await createGate?.future;
    final error = createError;
    if (error != null) throw error;
    sentIds.add(ticketId!);
    sentActions.add('create');
    return ticketId;
  }

  @override
  Future<void> editTicket({
    required String ticketId,
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    final error = editError;
    if (error != null) throw error;
    sentIds.add(ticketId);
    sentActions.add('edit');
  }

  @override
  Future<void> cancelTicket(String ticketId) async {
    final error = cancelError;
    if (error != null) throw error;
    sentIds.add(ticketId);
    sentActions.add('cancel');
  }

  @override
  Future<Ticket?> getTicket(String ticketId) async => serverTicket;
}

void main() {
  late Database database;
  late SqliteLocalCache cache;
  late _FakeTicketService service;
  late TicketProvider provider;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    cache = SqliteLocalCache(openDatabase: () async => database);
    service = _FakeTicketService();
    provider = TicketProvider(
      ticketService: service,
      localCache: cache,
      haptic: () async {},
    );
    await provider.activateUser(_user);
  });

  tearDown(() async {
    provider.dispose();
    await database.close();
  });

  test('offline create is enqueued and remains visible as pending', () async {
    provider.setConnectivity(ConnectivityStatus.offline);

    final id = await _createTicket(provider);
    final queue = await provider.outboxFor(_user.uid);
    final tickets = await cache.getTickets(_user.uid);

    expect(id, 'ticket-1');
    expect(queue.single.action, OutboxActionType.create);
    expect(tickets.single.syncStatus, TicketSyncStatus.pending);
    expect(service.sentIds, isEmpty);
  });

  test('online transition sends queued work and removes it from the outbox',
      () async {
    provider.setConnectivity(ConnectivityStatus.offline);
    final id = await _createTicket(provider);

    provider.setConnectivity(ConnectivityStatus.online);
    await _waitUntil(() async => (await provider.outboxFor(_user.uid)).isEmpty);

    expect(service.sentIds, [id]);
    expect(await provider.outboxFor(_user.uid), isEmpty);
    final stored = (await cache.getTickets(_user.uid)).single;
    expect(provider.decorateTicket(stored).syncStatus, TicketSyncStatus.sent);
  });

  test('network failure retains the item as pending for retry', () async {
    provider.setConnectivity(ConnectivityStatus.offline);
    await _createTicket(provider);
    service.createError = _firestoreError('unavailable');

    provider.setConnectivity(ConnectivityStatus.online);
    await _waitUntil(() async {
      final queue = await provider.outboxFor(_user.uid);
      return queue.isNotEmpty && queue.single.retryCount == 1;
    });

    final item = (await provider.outboxFor(_user.uid)).single;
    expect(item.status, OutboxStatus.pending);
    expect(item.retryCount, 1);
    expect((await cache.getTickets(_user.uid)).single.syncStatus,
        TicketSyncStatus.pending);
  });

  test('concurrent sync triggers do not send the same item twice', () async {
    provider.setConnectivity(ConnectivityStatus.offline);
    final id = await _createTicket(provider);
    service.createGate = Completer<void>();

    provider.setConnectivity(ConnectivityStatus.online);
    final syncOne = provider.syncOutbox();
    final syncTwo = provider.syncOutbox();
    service.createGate!.complete();
    await Future.wait([syncOne, syncTwo]);
    await _waitUntil(() async => (await provider.outboxFor(_user.uid)).isEmpty);

    expect(service.sentIds, [id]);
  });

  test('queued tickets are sent in FIFO order', () async {
    provider.setConnectivity(ConnectivityStatus.offline);
    await _createTicket(provider);
    await _createTicket(provider);
    await _createTicket(provider);

    provider.setConnectivity(ConnectivityStatus.online);
    await _waitUntil(() async => (await provider.outboxFor(_user.uid)).isEmpty);

    expect(service.sentIds, ['ticket-1', 'ticket-2', 'ticket-3']);
  });

  test('edit rejected by server becomes failed and restores server data',
      () async {
    await cache.saveTicket(_user.uid, _ticket());
    service.editError = _firestoreError('permission-denied');
    service.serverTicket = _ticket(title: 'Sudah diproses');
    provider.setConnectivity(ConnectivityStatus.offline);

    expect(
      await provider.editTicket(
        ticketId: 'ticket-existing',
        title: 'Perubahan lokal',
        description: 'Deskripsi',
        category: 'Printer',
        priority: 'Biasa',
      ),
      isTrue,
    );
    provider.setConnectivity(ConnectivityStatus.online);
    await _waitUntil(() async {
      final queue = await provider.outboxFor(_user.uid);
      return queue.isNotEmpty && queue.single.status == OutboxStatus.failed;
    });

    final queued = (await provider.outboxFor(_user.uid)).single;
    expect(queued.errorMessage,
        'Tidak dapat dikirim: tiket sudah diproses admin.');
    expect((await cache.getTickets(_user.uid)).single.title, 'Sudah diproses');
  });

  test('cancel rejected by server is not retried indefinitely', () async {
    await cache.saveTicket(_user.uid, _ticket());
    service.cancelError = _firestoreError('not-found');
    service.serverTicket = null;
    provider.setConnectivity(ConnectivityStatus.offline);

    expect(await provider.cancelTicket('ticket-existing'), isTrue);
    provider.setConnectivity(ConnectivityStatus.online);
    await _waitUntil(() async {
      final queue = await provider.outboxFor(_user.uid);
      return queue.isNotEmpty && queue.single.status == OutboxStatus.failed;
    });

    final queued = (await provider.outboxFor(_user.uid)).single;
    expect(queued.status, OutboxStatus.failed);
    expect(queued.errorMessage,
        'Tidak dapat dikirim: tiket sudah diproses admin.');
    expect(await cache.getTickets(_user.uid), isEmpty);
  });

  test('logout removes all local cache and queued actions for that uid',
      () async {
    provider.setConnectivity(ConnectivityStatus.offline);
    await _createTicket(provider);

    await provider.clearUserData(_user.uid);

    expect(await cache.getTickets(_user.uid), isEmpty);
    expect(await provider.outboxFor(_user.uid), isEmpty);
  });
}

const _user = AppUser(
  uid: 'user-1',
  name: 'Ayu',
  email: 'ayu@example.com',
  role: UserRoles.employee,
  companyId: 'company-1',
  companyCode: 'IT001',
  status: AccountStatuses.active,
  department: 'IT',
);

Ticket _ticket({String title = 'Tiket'}) => Ticket(
      id: 'ticket-existing',
      ticketNumber: 'HD-EXIST',
      title: title,
      description: 'Deskripsi',
      category: 'Printer',
      priority: 'Biasa',
      status: TicketStatuses.waiting,
      userId: _user.uid,
      userName: _user.name,
      companyId: _user.companyId,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

FirebaseException _firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

Future<String?> _createTicket(TicketProvider provider) => provider.createTicket(
      user: _user,
      title: 'Printer rusak',
      description: 'Tidak bisa mencetak.',
      category: 'Printer',
      priority: 'Biasa',
    );

Future<void> _waitUntil(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Kondisi antrean tidak tercapai.');
}
