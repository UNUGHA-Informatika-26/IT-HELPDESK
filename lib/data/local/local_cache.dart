import '../../models/app_user.dart';
import '../../models/ticket.dart';
import '../../models/ticket_update.dart';

enum OutboxActionType { create, edit, cancel }

class OutboxItem {
  const OutboxItem({
    required this.localId,
    required this.uid,
    required this.action,
    required this.ticketId,
    required this.payload,
    required this.createdAt,
    this.status = OutboxStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
  });

  final String localId;
  final String uid;
  final OutboxActionType action;
  final String ticketId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final OutboxStatus status;
  final int retryCount;
  final String? errorMessage;

  OutboxItem copyWith({
    OutboxStatus? status,
    int? retryCount,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) =>
      OutboxItem(
        localId: localId,
        uid: uid,
        action: action,
        ticketId: ticketId,
        payload: payload,
        createdAt: createdAt,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        errorMessage:
            clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      );
}

enum OutboxStatus { pending, failed }

abstract interface class LocalCache {
  Future<List<Ticket>> getTickets(String uid);
  Future<void> saveTickets(String uid, List<Ticket> tickets);
  Future<void> saveTicket(String uid, Ticket ticket);
  Future<void> removeTicket(String uid, String ticketId);
  Future<List<TicketUpdate>> getUpdates(String ticketId);
  Future<void> saveUpdates(String ticketId, List<TicketUpdate> updates);
  Future<void> saveProfile(AppUser user);
  Future<AppUser?> getProfile(String uid);
  Future<void> saveCounts(String uid, Map<String, int> counts);
  Future<Map<String, int>?> getCounts(String uid);
  Future<DateTime?> getLastUpdated(String uid);
  Future<void> enqueue(OutboxItem item);
  Future<List<OutboxItem>> getOutbox(String uid);
  Future<void> updateOutbox(OutboxItem item);
  Future<void> removeOutbox(String localId);
  Future<void> clearUser(String uid);
}

class NoopLocalCache implements LocalCache {
  const NoopLocalCache();

  @override
  Future<void> clearUser(String uid) async {}
  @override
  Future<List<Ticket>> getTickets(String uid) async => [];
  @override
  Future<void> saveTickets(String uid, List<Ticket> tickets) async {}
  @override
  Future<void> saveTicket(String uid, Ticket ticket) async {}
  @override
  Future<void> removeTicket(String uid, String ticketId) async {}
  @override
  Future<List<TicketUpdate>> getUpdates(String ticketId) async => [];
  @override
  Future<void> saveUpdates(String ticketId, List<TicketUpdate> updates) async {}
  @override
  Future<void> saveProfile(AppUser user) async {}
  @override
  Future<AppUser?> getProfile(String uid) async => null;
  @override
  Future<void> saveCounts(String uid, Map<String, int> counts) async {}
  @override
  Future<Map<String, int>?> getCounts(String uid) async => null;
  @override
  Future<DateTime?> getLastUpdated(String uid) async => null;
  @override
  Future<void> enqueue(OutboxItem item) async {}
  @override
  Future<List<OutboxItem>> getOutbox(String uid) async => [];
  @override
  Future<void> updateOutbox(OutboxItem item) async {}
  @override
  Future<void> removeOutbox(String localId) async {}
}
