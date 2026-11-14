import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../data/local/local_cache.dart';
import '../data/local/local_cache_factory.dart';
import '../features/connectivity/connectivity_cubit.dart';
import '../models/app_user.dart';
import '../models/ticket.dart';
import '../models/ticket_update.dart';
import '../services/firebase_error_messages.dart';
import '../services/ticket_service.dart';

class TicketProvider extends ChangeNotifier {
  TicketProvider({
    TicketService? ticketService,
    LocalCache? localCache,
    Future<void> Function()? haptic,
  })  : _ticketService = ticketService ?? TicketService(),
        _cache = localCache ?? createLocalCache(),
        _haptic = haptic ?? HapticFeedback.lightImpact;

  final TicketService _ticketService;
  final LocalCache _cache;
  final Future<void> Function() _haptic;
  final Map<String, StreamController<void>> _ticketEvents = {};
  final Map<String, List<Ticket>> _serverTickets = {};
  final Map<String, Set<String>> _recentlySent = {};
  final Map<String, Timer> _sentTimers = {};
  bool _isBusy = false;
  bool _isOffline = false;
  bool _networkAvailable = true;
  bool _syncing = false;
  String? _error;
  String? _countsError;
  String? _loadingCountsFor;
  String? _activeUid;
  DateTime? _lastUpdated;
  Timer? _retryTimer;
  Map<String, int> _counts = {};

  bool get isBusy => _isBusy;
  bool get isOffline => _isOffline;
  String? get error => _error;
  String? get countsError => _countsError;
  DateTime? get lastUpdated => _lastUpdated;
  Map<String, int> get counts => Map.unmodifiable(_counts);

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void setConnectivity(ConnectivityStatus status) {
    _networkAvailable = status == ConnectivityStatus.online;
    if (!_networkAvailable) {
      _isOffline = true;
      notifyListeners();
      return;
    }
    _isOffline = false;
    notifyListeners();
    unawaited(syncOutbox());
  }

  Future<void> activateUser(AppUser user) async {
    _activate(user.uid);
    await _cache.saveProfile(user);
    _counts = await _cache.getCounts(user.uid) ?? _counts;
    if (_networkAvailable) await syncOutbox(uid: user.uid);
    notifyListeners();
  }

  Future<void> refreshTickets(AppUser user) async {
    _activate(user.uid);
    if (!_networkAvailable) {
      _isOffline = true;
      _publish(user.uid);
      notifyListeners();
      return;
    }
    try {
      final tickets = await _ticketService.fetchTickets(
        userId: user.isAdmin ? null : user.uid,
        companyId: user.companyId,
      );
      final queued = await _cache.getOutbox(user.uid);
      final queuedIds = queued.map((item) => item.ticketId).toSet();
      await _cache.saveTickets(
        user.uid,
        tickets.where((ticket) => !queuedIds.contains(ticket.id)).toList(),
      );
      _serverTickets[user.uid] = tickets;
      _lastUpdated = DateTime.now();
      _isOffline = false;
      _publish(user.uid);
      notifyListeners();
    } on FirebaseException catch (exception) {
      _handleStreamError(exception);
      _publish(user.uid);
    }
  }

  Future<void> clearUserData(String uid) async {
    await _cache.clearUser(uid);
    _ticketEvents.remove(uid)?.close();
    _serverTickets.remove(uid);
    _recentlySent.remove(uid);
    for (final key in _sentTimers.keys.where((key) => key.startsWith('$uid:')).toList()) {
      _sentTimers.remove(key)?.cancel();
    }
    if (_activeUid == uid) {
      _activeUid = null;
      _counts = {};
      _lastUpdated = null;
    }
    notifyListeners();
  }

  Future<bool> isQueued(String uid, String ticketId) async =>
      (await _cache.getOutbox(uid)).any((item) => item.ticketId == ticketId);

  Future<void> retryTicket(String ticketId) async {
    final uid = _activeUid;
    if (uid == null) return;
    final item = (await _cache.getOutbox(uid))
        .where((queued) => queued.ticketId == ticketId)
        .firstOrNull;
    if (item != null) await retryOutbox(item.localId);
  }

  Future<void> removeQueuedTicket(String ticketId) async {
    final uid = _activeUid;
    if (uid == null) return;
    final item = (await _cache.getOutbox(uid))
        .where((queued) => queued.ticketId == ticketId)
        .firstOrNull;
    if (item != null) await removeOutboxItem(item.localId);
  }

  Stream<List<Ticket>> watchTickets(AppUser user) {
    final uid = user.uid;
    _activate(uid);
    return Stream<List<Ticket>>.multi((controller) {
      final events = _ticketEvents.putIfAbsent(
        uid,
        () => StreamController<void>.broadcast(),
      );
      StreamSubscription<void>? eventSubscription;
      StreamSubscription<List<Ticket>>? serverSubscription;
      var cancelled = false;

      Future<void> emitCurrent() async {
        if (cancelled) return;
        try {
          controller.add(await _mergedTickets(uid, _serverTickets[uid] ?? []));
        } on Object {
          _setOffline();
        }
      }

      eventSubscription = events.stream.listen((_) => unawaited(emitCurrent()));
      unawaited(() async {
        try {
          final cached = await _cache.getTickets(uid);
          if (cancelled) return;
          _lastUpdated = await _cache.getLastUpdated(uid);
          controller.add(await _mergedTickets(uid, cached));
          serverSubscription = _ticketService
              .watchTickets(
            userId: user.isAdmin ? null : user.uid,
            companyId: user.companyId,
          )
              .listen(
            (tickets) => unawaited(_acceptServerTickets(
              uid,
              tickets,
              controller,
              cancelled: () => cancelled,
            )),
            onError: (Object error, StackTrace stackTrace) {
              _handleStreamError(error);
              unawaited(emitCurrent());
            },
          );
        } on Object catch (error) {
          _handleStreamError(error);
          if (!cancelled) controller.add(const []);
        }
      }());
      controller.onCancel = () async {
        cancelled = true;
        await eventSubscription?.cancel();
        await serverSubscription?.cancel();
      };
    });
  }

  Future<void> _acceptServerTickets(
    String uid,
    List<Ticket> tickets,
    MultiStreamController<List<Ticket>> controller, {
    required bool Function() cancelled,
  }) async {
    if (_activeUid != uid || cancelled()) return;
    _serverTickets[uid] = tickets;
    try {
      final queued = await _cache.getOutbox(uid);
      final queuedIds = queued.map((item) => item.ticketId).toSet();
      await _cache.saveTickets(
        uid,
        tickets.where((ticket) => !queuedIds.contains(ticket.id)).toList(),
      );
      _lastUpdated = DateTime.now();
      _isOffline = false;
      controller.add(await _mergedTickets(uid, tickets));
      notifyListeners();
    } on Object catch (error) {
      _handleStreamError(error);
      controller.add(tickets);
    }
  }

  Future<List<Ticket>> _mergedTickets(
    String uid,
    List<Ticket> base,
  ) async {
    final local = await _cache.getTickets(uid);
    final queue = await _cache.getOutbox(uid);
    final queuedIds = queue.map((item) => item.ticketId).toSet();
    final localById = {for (final ticket in local) ticket.id: ticket};
    final ticketsById = {for (final ticket in base) ticket.id: ticket};
    for (final ticketId in queuedIds) {
      final pendingTicket = localById[ticketId];
      if (pendingTicket != null) ticketsById[ticketId] = pendingTicket;
    }
    final recentlySent = _recentlySent[uid] ?? {};
    for (final ticketId in recentlySent) {
      final ticket = ticketsById[ticketId] ?? localById[ticketId];
      if (ticket != null) {
        ticketsById[ticketId] = ticket.copyWith(
          syncStatus: TicketSyncStatus.sent,
          clearSyncError: true,
        );
      }
    }
    final result = ticketsById.values.toList()
      ..sort((first, second) =>
          (second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
            first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ));
    return result;
  }

  Stream<Ticket?> watchTicket(String ticketId, {String? uid}) {
    final ownerUid = uid ?? _activeUid;
    return Stream<Ticket?>.multi((controller) {
      StreamSubscription<Ticket?>? subscription;
      var cancelled = false;
      unawaited(() async {
        if (ownerUid != null) {
          try {
            final cached = (await _cache.getTickets(ownerUid))
                .where((ticket) => ticket.id == ticketId)
                .firstOrNull;
            if (!cancelled && cached != null) controller.add(cached);
          } on Object {
            _setOffline();
          }
        }
        subscription = _ticketService.watchTicket(ticketId).listen(
          (ticket) => unawaited(() async {
            try {
              if (ownerUid == null || cancelled) return;
              final item = (await _cache.getOutbox(ownerUid))
                  .where((queued) => queued.ticketId == ticketId)
                  .firstOrNull;
              if (ticket == null) {
                if (item?.action == OutboxActionType.create) {
                  final pending = (await _cache.getTickets(ownerUid))
                      .where((cachedTicket) => cachedTicket.id == ticketId)
                      .firstOrNull;
                  if (!cancelled && pending != null) controller.add(pending);
                  return;
                }
                await _cache.removeTicket(ownerUid, ticketId);
              } else {
                await _cache.saveTicket(ownerUid, ticket);
              }
              final result = ticket == null || item == null
                  ? ticket
                  : ticket.copyWith(
                      syncStatus: item.status == OutboxStatus.failed
                          ? TicketSyncStatus.failed
                          : TicketSyncStatus.pending,
                      syncError: item.errorMessage,
                    );
              if (!cancelled) controller.add(result);
            } on Object {
              _setOffline();
              if (!cancelled) controller.add(null);
            }
          }()),
          onError: (Object error, StackTrace stackTrace) {
            _handleStreamError(error);
            if (!cancelled) controller.add(null);
          },
        );
      }());
      controller.onCancel = () async {
        cancelled = true;
        await subscription?.cancel();
      };
    });
  }

  Stream<List<TicketUpdate>> watchUpdates(String ticketId, {String? uid}) =>
      Stream<List<TicketUpdate>>.multi((controller) {
        StreamSubscription<List<TicketUpdate>>? subscription;
        var cancelled = false;
        unawaited(() async {
          try {
            final cached = await _cache.getUpdates(ticketId);
            if (!cancelled && cached.isNotEmpty) controller.add(cached);
          } on Object {
            _setOffline();
          }
          subscription = _ticketService.watchUpdates(ticketId).listen(
            (updates) => unawaited(() async {
              try {
                await _cache.saveUpdates(ticketId, updates);
                if (!cancelled) controller.add(updates);
              } on Object {
                _setOffline();
                if (!cancelled) controller.add(const []);
              }
            }()),
            onError: (Object error, StackTrace stackTrace) {
              _handleStreamError(error);
              if (!cancelled) controller.add(const []);
            },
          );
        }());
        controller.onCancel = () async {
          cancelled = true;
          await subscription?.cancel();
        };
      });

  Future<void> loadCounts(
    AppUser? user, {
    bool Function()? isCurrent,
  }) async {
    if (user == null || !(isCurrent?.call() ?? true)) return;
    _activate(user.uid);
    if (_loadingCountsFor == user.uid) return;
    _loadingCountsFor = user.uid;
    _countsError = null;
    try {
      if (!_networkAvailable) throw StateError('offline');
      final values = await Future.wait(
        TicketStatuses.all.map(
          (status) => _ticketService.countTickets(
            userId: user.isAdmin ? null : user.uid,
            companyId: user.companyId,
            status: status,
          ),
        ),
      );
      if (!(isCurrent?.call() ?? true)) return;
      _counts = Map.fromIterables(TicketStatuses.all, values);
      _counts['total'] =
          values.fold(0, (totalCount, value) => totalCount + value);
      await _cache.saveCounts(user.uid, _counts);
      _isOffline = false;
    } on Object {
      if (!(isCurrent?.call() ?? true)) return;
      _counts = await _cache.getCounts(user.uid) ?? _counts;
      _countsError =
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      _setOffline();
    } finally {
      if (_loadingCountsFor == user.uid) {
        _loadingCountsFor = null;
        if (isCurrent?.call() ?? true) notifyListeners();
      }
    }
  }

  Future<String?> createTicket({
    required AppUser user,
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    _setBusy(true);
    _error = null;
    final ticketId = _ticketService.newTicketId();
    final now = DateTime.now();
    final ticket = Ticket(
      id: ticketId,
      ticketNumber: ticketNumberForId(ticketId),
      title: title.trim(),
      description: description.trim(),
      category: category,
      priority: priority,
      status: TicketStatuses.waiting,
      userId: user.uid,
      userName: user.name,
      companyId: user.companyId,
      createdAt: now,
      updatedAt: now,
      syncStatus: TicketSyncStatus.pending,
    );
    try {
      if (!_networkAvailable) {
        await _queue(user.uid, OutboxActionType.create, ticket, {
          'title': ticket.title,
          'description': ticket.description,
          'category': ticket.category,
          'priority': ticket.priority,
          'userName': user.name,
          'companyId': user.companyId,
        });
        return ticketId;
      }
      await _ticketService.createTicket(
        user: user,
        title: title,
        description: description,
        category: category,
        priority: priority,
        ticketId: ticketId,
      );
      await _cache.saveTicket(
          user.uid,
          ticket.copyWith(
            syncStatus: TicketSyncStatus.sent,
          ));
      _markSent(user.uid, ticketId);
      _publish(user.uid);
      return ticketId;
    } on FirebaseException catch (exception) {
      if (_isNetworkError(exception)) {
        _setOffline();
        await _queue(user.uid, OutboxActionType.create, ticket, {
          'title': ticket.title,
          'description': ticket.description,
          'category': ticket.category,
          'priority': ticket.priority,
          'userName': user.name,
          'companyId': user.companyId,
        });
        return ticketId;
      }
      _error = firestoreErrorMessage(exception);
      return null;
    } on Object {
      _error = 'Tiket gagal disimpan. Silakan coba lagi.';
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> editTicket({
    required String ticketId,
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    final uid = _activeUid;
    if (uid == null) return false;
    return _mutateEmployeeAction(uid, ticketId, OutboxActionType.edit, {
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'priority': priority,
    });
  }

  Future<bool> cancelTicket(String ticketId) async {
    final uid = _activeUid;
    if (uid == null) return false;
    return _mutateEmployeeAction(uid, ticketId, OutboxActionType.cancel, {});
  }

  Future<bool> _mutateEmployeeAction(
    String uid,
    String ticketId,
    OutboxActionType action,
    Map<String, dynamic> payload,
  ) async {
    _setBusy(true);
    _error = null;
    try {
      final tickets = await _cache.getTickets(uid);
      final current =
          tickets.where((ticket) => ticket.id == ticketId).firstOrNull;
      if (current == null || !current.canEdit) {
        _error = 'Tiket tidak dapat diubah karena bukan berstatus Menunggu.';
        return false;
      }
      final optimistic = current.copyWith(
        title: payload['title'] as String?,
        description: payload['description'] as String?,
        category: payload['category'] as String?,
        priority: payload['priority'] as String?,
        status: action == OutboxActionType.cancel
            ? TicketStatuses.cancelled
            : current.status,
        updatedAt: DateTime.now(),
        syncStatus: TicketSyncStatus.pending,
      );
      if (!_networkAvailable) {
        await _queue(uid, action, optimistic, payload);
        return true;
      }
      if (action == OutboxActionType.edit) {
        await _ticketService.editTicket(
          ticketId: ticketId,
          title: payload['title'] as String,
          description: payload['description'] as String,
          category: payload['category'] as String,
          priority: payload['priority'] as String,
        );
      } else {
        await _ticketService.cancelTicket(ticketId);
      }
      await _cache.saveTicket(
        uid,
        optimistic.copyWith(syncStatus: TicketSyncStatus.sent),
      );
      _markSent(uid, ticketId);
      _publish(uid);
      return true;
    } on FirebaseException catch (exception) {
      if (_isNetworkError(exception)) {
        _setOffline();
        final current = (await _cache.getTickets(uid))
            .where((ticket) => ticket.id == ticketId)
            .firstOrNull;
        if (current != null) {
          final optimistic = current.copyWith(
            title: payload['title'] as String?,
            description: payload['description'] as String?,
            category: payload['category'] as String?,
            priority: payload['priority'] as String?,
            status: action == OutboxActionType.cancel
                ? TicketStatuses.cancelled
                : current.status,
            updatedAt: DateTime.now(),
            syncStatus: TicketSyncStatus.pending,
          );
          await _queue(uid, action, optimistic, payload);
          return true;
        }
      }
      _error = firestoreErrorMessage(exception);
      return false;
    } on Object {
      _error = 'Perubahan tiket gagal disimpan. Silakan coba lagi.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _queue(
    String uid,
    OutboxActionType action,
    Ticket ticket,
    Map<String, dynamic> payload,
  ) async {
    final item = OutboxItem(
      localId: '${ticket.id}-${DateTime.now().microsecondsSinceEpoch}',
      uid: uid,
      action: action,
      ticketId: ticket.id,
      payload: payload,
      createdAt: DateTime.now(),
    );
    await _cache.enqueue(item);
    await _cache.saveTicket(
      uid,
      ticket.copyWith(syncStatus: TicketSyncStatus.pending),
    );
    _activeUid = uid;
    if (!kIsWeb) unawaited(_haptic());
    _publish(uid);
    notifyListeners();
  }

  Future<void> syncOutbox({String? uid}) async {
    final ownerUid = uid ?? _activeUid;
    if (ownerUid == null || !_networkAvailable || _syncing) return;
    _syncing = true;
    try {
      final queue = await _cache.getOutbox(ownerUid);
      for (final item in queue) {
        if (item.status == OutboxStatus.failed) continue;
        try {
          await _sendOutboxItem(item);
          await _cache.removeOutbox(item.localId);
          _markSent(ownerUid, item.ticketId);
          _publish(ownerUid);
          notifyListeners();
        } on FirebaseException catch (exception) {
          if (_isNetworkError(exception)) {
            _isOffline = true;
            await _cache.updateOutbox(item.copyWith(
              retryCount: item.retryCount + 1,
            ));
            _scheduleRetry(ownerUid, item.retryCount + 1);
            notifyListeners();
            break;
          }
          if (item.action != OutboxActionType.create &&
              _isConflict(exception)) {
            final message = 'Tidak dapat dikirim: tiket sudah diproses admin.';
            await _cache.updateOutbox(item.copyWith(
              status: OutboxStatus.failed,
              errorMessage: message,
            ));
            try {
              final serverTicket =
                  await _ticketService.getTicket(item.ticketId);
              if (serverTicket == null) {
                await _cache.removeTicket(ownerUid, item.ticketId);
              } else {
                await _cache.saveTicket(ownerUid, serverTicket);
              }
            } on FirebaseException catch (refreshError) {
              _handleStreamError(refreshError);
            }
            _publish(ownerUid);
            notifyListeners();
            continue;
          }
          await _cache.updateOutbox(item.copyWith(
            status: OutboxStatus.failed,
            errorMessage: firestoreErrorMessage(exception),
          ));
          if (item.action != OutboxActionType.create) {
            try {
              final serverTicket =
                  await _ticketService.getTicket(item.ticketId);
              if (serverTicket == null) {
                await _cache.removeTicket(ownerUid, item.ticketId);
              } else {
                await _cache.saveTicket(ownerUid, serverTicket);
              }
            } on FirebaseException catch (refreshError) {
              _handleStreamError(refreshError);
            }
          }
          _publish(ownerUid);
          notifyListeners();
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _sendOutboxItem(OutboxItem item) async {
    switch (item.action) {
      case OutboxActionType.create:
        final profile = await _cache.getProfile(item.uid);
        final user = profile ??
            AppUser(
              uid: item.uid,
              name: item.payload['userName'] as String? ?? '',
              email: '',
              role: UserRoles.employee,
              companyId: item.payload['companyId'] as String? ?? '',
              companyCode: '',
              status: AccountStatuses.active,
              department: '',
            );
        await _ticketService.createTicket(
          user: user,
          title: item.payload['title'] as String,
          description: item.payload['description'] as String,
          category: item.payload['category'] as String,
          priority: item.payload['priority'] as String,
          ticketId: item.ticketId,
        );
      case OutboxActionType.edit:
        await _ticketService.editTicket(
          ticketId: item.ticketId,
          title: item.payload['title'] as String,
          description: item.payload['description'] as String,
          category: item.payload['category'] as String,
          priority: item.payload['priority'] as String,
        );
      case OutboxActionType.cancel:
        await _ticketService.cancelTicket(item.ticketId);
    }
  }

  Future<void> retryOutbox(String localId) async {
    final uid = _activeUid;
    if (uid == null) return;
    final queue = await _cache.getOutbox(uid);
    final item = queue.where((entry) => entry.localId == localId).firstOrNull;
    if (item == null) return;
    await _cache.updateOutbox(item.copyWith(
      status: OutboxStatus.pending,
      clearErrorMessage: true,
    ));
    await syncOutbox(uid: uid);
    _publish(uid);
  }

  Future<void> removeOutboxItem(String localId) async {
    final uid = _activeUid;
    if (uid == null) return;
    final queue = await _cache.getOutbox(uid);
    final item = queue.where((entry) => entry.localId == localId).firstOrNull;
    if (item == null) return;
    await _cache.removeOutbox(localId);
    if (item.action == OutboxActionType.create) {
      await _cache.removeTicket(uid, item.ticketId);
    } else if (_networkAvailable) {
      try {
        final serverTicket = await _ticketService.getTicket(item.ticketId);
        if (serverTicket == null) {
          await _cache.removeTicket(uid, item.ticketId);
        } else {
          await _cache.saveTicket(uid, serverTicket);
        }
      } on FirebaseException catch (exception) {
        _handleStreamError(exception);
      }
    }
    _publish(uid);
  }

  Future<List<OutboxItem>> outboxFor(String uid) => _cache.getOutbox(uid);

  Ticket decorateTicket(Ticket ticket) {
    if (_recentlySent[_activeUid]?.contains(ticket.id) ?? false) {
      return ticket.copyWith(syncStatus: TicketSyncStatus.sent);
    }
    return ticket;
  }

  Future<List<Ticket>?> ticketsInRange({
    required String companyId,
    required DateTime start,
    required DateTime end,
  }) async {
    _error = null;
    if (!_networkAvailable) {
      _error = 'Aksi ini membutuhkan koneksi internet.';
      notifyListeners();
      return null;
    }
    try {
      return await _ticketService.ticketsInRange(
        companyId: companyId,
        start: start,
        end: end,
      );
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
      _setOffline();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteOwnTicket(String ticketId) =>
      _mutate(() => _ticketService.deleteOwnTicket(ticketId));

  Future<bool> deleteTicketAsAdmin({
    required Ticket ticket,
    required AppUser admin,
    required String reason,
  }) =>
      _mutate(
        () => _ticketService.deleteTicketAsAdmin(
          ticket: ticket,
          admin: admin,
          reason: reason,
        ),
      );

  Future<bool> handleTicket({
    required Ticket ticket,
    required AppUser admin,
    required String status,
    required String note,
  }) =>
      _mutate(
        () => _ticketService.handleTicket(
          ticket: ticket,
          admin: admin,
          status: status,
          note: note,
        ),
      );

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (!_networkAvailable) {
      _error = 'Aksi ini membutuhkan koneksi internet.';
      notifyListeners();
      return false;
    }
    _setBusy(true);
    _error = null;
    try {
      await operation();
      return true;
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
      if (_isNetworkError(exception)) _setOffline();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void _activate(String uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    _counts = {};
    _lastUpdated = null;
  }

  void _publish(String uid) {
    _ticketEvents[uid]?.add(null);
  }

  void _markSent(String uid, String ticketId) {
    if (!kIsWeb) unawaited(_haptic());
    _recentlySent.putIfAbsent(uid, () => {}).add(ticketId);
    _sentTimers.remove('$uid:$ticketId')?.cancel();
    _sentTimers['$uid:$ticketId'] = Timer(const Duration(seconds: 2), () {
      _recentlySent[uid]?.remove(ticketId);
      _sentTimers.remove('$uid:$ticketId');
      _publish(uid);
      notifyListeners();
    });
  }

  void _scheduleRetry(String uid, int retryCount) {
    _retryTimer?.cancel();
    const delays = [5, 15, 60];
    final seconds = delays[(retryCount - 1).clamp(0, delays.length - 1)];
    _retryTimer = Timer(Duration(seconds: seconds), () {
      if (_networkAvailable) unawaited(syncOutbox(uid: uid));
    });
  }

  void _handleStreamError(Object error) {
    _setOffline();
    if (error is FirebaseException && !_isNetworkError(error)) {
      _error = firestoreErrorMessage(error);
    }
  }

  void _setOffline() {
    _isOffline = true;
    notifyListeners();
  }

  bool _isNetworkError(FirebaseException exception) => {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
        'unknown',
      }.contains(exception.code);

  bool _isConflict(FirebaseException exception) =>
      exception.code == 'permission-denied' || exception.code == 'not-found';

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    for (final timer in _sentTimers.values) {
      timer.cancel();
    }
    for (final events in _ticketEvents.values) {
      events.close();
    }
    super.dispose();
  }
}
