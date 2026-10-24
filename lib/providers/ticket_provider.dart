import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/ticket.dart';
import '../models/ticket_update.dart';
import '../services/firebase_error_messages.dart';
import '../services/ticket_service.dart';

class TicketProvider extends ChangeNotifier {
  TicketProvider({TicketService? ticketService})
      : _ticketService = ticketService ?? TicketService();

  final TicketService _ticketService;
  bool _isBusy = false;
  String? _error;
  Map<String, int> _counts = {};

  bool get isBusy => _isBusy;
  String? get error => _error;
  Map<String, int> get counts => Map.unmodifiable(_counts);

  Stream<List<Ticket>> watchTickets(AppUser user) =>
      _ticketService.watchTickets(
        userId: user.isAdmin ? null : user.uid,
        companyId: user.companyId,
      );

  Stream<Ticket?> watchTicket(String ticketId) =>
      _ticketService.watchTicket(ticketId);

  Stream<List<TicketUpdate>> watchUpdates(String ticketId) =>
      _ticketService.watchUpdates(ticketId);

  Future<void> loadCounts(AppUser user) async {
    _error = null;
    try {
      final results = await Future.wait(
        TicketStatuses.all.map(
          (status) => _ticketService.countTickets(
            userId: user.isAdmin ? null : user.uid,
            companyId: user.companyId,
            status: status,
          ),
        ),
      );
      _counts = Map.fromIterables(TicketStatuses.all, results);
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
    }
    notifyListeners();
  }

  Future<String?> createTicket({
    required AppUser user,
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      final id = await _ticketService.createTicket(
        user: user,
        title: title,
        description: description,
        category: category,
        priority: priority,
      );
      return id;
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> editTicket({
    required String ticketId,
    required String title,
    required String description,
    required String category,
    required String priority,
  }) =>
      _mutate(() => _ticketService.editTicket(
            ticketId: ticketId,
            title: title,
            description: description,
            category: category,
            priority: priority,
          ));

  Future<bool> cancelTicket(String ticketId) =>
      _mutate(() => _ticketService.cancelTicket(ticketId));

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

  Future<List<Ticket>?> ticketsInRange({
    required String companyId,
    required DateTime start,
    required DateTime end,
  }) async {
    _error = null;
    try {
      return await _ticketService.ticketsInRange(
        companyId: companyId,
        start: start,
        end: end,
      );
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
      notifyListeners();
      return null;
    }
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
