import 'dart:convert';

import '../../models/app_user.dart';
import '../../models/ticket.dart';
import '../../models/ticket_update.dart';
import 'local_cache.dart';

class LocalModelMapper {
  const LocalModelMapper._();

  static Map<String, Object?> ticketToRow(
    String uid,
    Ticket ticket, {
    DateTime? syncedAt,
  }) =>
      {
        'id': ticket.id,
        'uid_pemilik': uid,
        'company_id': ticket.companyId,
        'ticket_number': ticket.ticketNumber,
        'title': ticket.title,
        'description': ticket.description,
        'category': ticket.category,
        'priority': ticket.priority,
        'status': ticket.status,
        'created_at': ticket.createdAt?.toIso8601String(),
        'updated_at': ticket.updatedAt?.toIso8601String(),
        'synced_at': (syncedAt ?? DateTime.now()).toIso8601String(),
      };

  static Ticket ticketFromRow(
    Map<String, Object?> row, {
    OutboxItem? outbox,
  }) =>
      Ticket(
        id: row['id']! as String,
        ticketNumber: row['ticket_number']! as String,
        title: row['title']! as String,
        description: row['description']! as String,
        category: row['category']! as String,
        priority: row['priority']! as String,
        status: row['status']! as String,
        userId: row['uid_pemilik']! as String,
        userName: '',
        companyId: row['company_id']! as String,
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
        syncStatus: outbox == null
            ? TicketSyncStatus.idle
            : outbox.status == OutboxStatus.failed
                ? TicketSyncStatus.failed
                : TicketSyncStatus.pending,
        syncError: outbox?.errorMessage,
      );

  static Map<String, Object?> updateToRow(
    String ticketId,
    TicketUpdate update,
  ) =>
      {
        'id': update.id,
        'ticket_id': ticketId,
        'from_status': update.oldStatus,
        'to_status': update.newStatus,
        'note': update.note,
        'by_name': update.adminName,
        'created_at': update.createdAt?.toIso8601String(),
      };

  static TicketUpdate updateFromRow(Map<String, Object?> row) => TicketUpdate(
        id: row['id']! as String,
        adminId: '',
        adminName: row['by_name']! as String,
        oldStatus: row['from_status']! as String,
        newStatus: row['to_status']! as String,
        note: row['note']! as String,
        createdAt: _date(row['created_at']),
      );

  static String profileToJson(AppUser user) => jsonEncode(user.toMap());

  static AppUser profileFromJson(String uid, String json) =>
      AppUser.fromMap(uid, jsonDecode(json) as Map<String, dynamic>);

  static Map<String, Object?> outboxToRow(OutboxItem item) => {
        'local_id': item.localId,
        'uid': item.uid,
        'jenis_aksi': switch (item.action) {
          OutboxActionType.create => 'buat_tiket',
          OutboxActionType.edit => 'edit_tiket',
          OutboxActionType.cancel => 'batalkan_tiket',
        },
        'ticket_id': item.ticketId,
        'payload': jsonEncode(item.payload),
        'created_at': item.createdAt.toIso8601String(),
        'status': item.status.name,
        'retry_count': item.retryCount,
        'pesan_error': item.errorMessage,
      };

  static OutboxItem outboxFromRow(Map<String, Object?> row) => OutboxItem(
        localId: row['local_id']! as String,
        uid: row['uid']! as String,
        action: switch (row['jenis_aksi']) {
          'buat_tiket' => OutboxActionType.create,
          'edit_tiket' => OutboxActionType.edit,
          'batalkan_tiket' => OutboxActionType.cancel,
          _ => throw StateError('Jenis aksi antrean tidak dikenal.'),
        },
        ticketId: row['ticket_id']! as String,
        payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(row['created_at']! as String),
        status: row['status'] == 'failed'
            ? OutboxStatus.failed
            : OutboxStatus.pending,
        retryCount: row['retry_count']! as int,
        errorMessage: row['pesan_error'] as String?,
      );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
