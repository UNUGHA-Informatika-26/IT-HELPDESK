import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/ticket.dart';
import '../models/ticket_update.dart';

class TicketService {
  TicketService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tickets =>
      _firestore.collection(AppConstants.ticketsCollection);

  Stream<List<Ticket>> watchTickets({
    required String? userId,
    required String? companyId,
  }) =>
      _tickets
          .where(userId == null ? 'companyId' : 'userId',
              isEqualTo: userId ?? companyId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((document) => Ticket.fromMap(document.id, document.data()))
              .toList());

  Stream<Ticket?> watchTicket(String id) => _tickets.doc(id).snapshots().map(
        (snapshot) => snapshot.exists && snapshot.data() != null
            ? Ticket.fromMap(snapshot.id, snapshot.data()!)
            : null,
      );

  Stream<List<TicketUpdate>> watchUpdates(String ticketId) => _tickets
      .doc(ticketId)
      .collection(AppConstants.updatesCollection)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((document) => TicketUpdate.fromMap(
                document.id,
                document.data(),
              ))
          .toList());

  Future<String> createTicket({
    required AppUser user,
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    final reference = _tickets.doc();
    final now = FieldValue.serverTimestamp();
    await reference.set({
      'ticketNumber': ticketNumberForId(reference.id),
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'priority': priority,
      'status': TicketStatuses.waiting,
      'userId': user.uid,
      'userName': user.name,
      'companyId': user.companyId,
      'createdAt': now,
      'updatedAt': now,
      'resolvedAt': null,
    });
    return reference.id;
  }

  Future<void> editTicket({
    required String ticketId,
    required String title,
    required String description,
    required String category,
    required String priority,
  }) =>
      _tickets.doc(ticketId).update({
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'priority': priority,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancelTicket(String ticketId) => _tickets.doc(ticketId).update({
        'status': TicketStatuses.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteOwnTicket(String ticketId) async {
    final ticketReference = _tickets.doc(ticketId);
    final updates =
        await ticketReference.collection(AppConstants.updatesCollection).get();
    final batch = _firestore.batch();
    for (final update in updates.docs) {
      batch.delete(update.reference);
    }
    batch.delete(ticketReference);
    await batch.commit();
  }

  Future<void> deleteTicketAsAdmin({
    required Ticket ticket,
    required AppUser admin,
    required String reason,
  }) async {
    final ticketReference = _tickets.doc(ticket.id);
    final updates =
        await ticketReference.collection(AppConstants.updatesCollection).get();
    final batch = _firestore.batch();
    for (final update in updates.docs) {
      batch.delete(update.reference);
    }
    batch.delete(ticketReference);
    batch.set(
      _firestore.collection(AppConstants.notificationsCollection).doc(),
      {
        'userId': ticket.userId,
        'companyId': admin.companyId,
        'type': 'ticket_deleted',
        'ticketNumber': ticket.ticketNumber,
        'ticketTitle': ticket.title,
        'reason': reason.trim(),
        'adminName': admin.name,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      },
    );
    await batch.commit();
  }

  Future<void> handleTicket({
    required Ticket ticket,
    required AppUser admin,
    required String status,
    required String note,
  }) async {
    final batch = _firestore.batch();
    final ticketReference = _tickets.doc(ticket.id);
    final updateReference =
        ticketReference.collection(AppConstants.updatesCollection).doc();

    batch.update(ticketReference, {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': status == TicketStatuses.completed
          ? FieldValue.serverTimestamp()
          : null,
    });
    batch.set(updateReference, {
      'adminId': admin.uid,
      'adminName': admin.name,
      'oldStatus': ticket.status,
      'newStatus': status,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<int> countTickets({
    required String? userId,
    required String? companyId,
    required String status,
  }) async {
    final base = _tickets.where(
      userId == null ? 'companyId' : 'userId',
      isEqualTo: userId ?? companyId,
    );
    final result = await base.where('status', isEqualTo: status).count().get();
    final count = result.count;
    if (count == null) {
      throw StateError('Firestore tidak mengembalikan hasil agregasi count.');
    }
    return count;
  }

  Future<List<Ticket>> ticketsInRange({
    required String companyId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _tickets
        .where('companyId', isEqualTo: companyId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((document) => Ticket.fromMap(document.id, document.data()))
        .toList();
  }
}
