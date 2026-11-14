import '../core/constants/app_constants.dart';
import 'app_user.dart';

class Ticket {
  const Ticket({
    required this.id,
    required this.ticketNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.userId,
    required this.userName,
    required this.companyId,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.syncStatus = TicketSyncStatus.idle,
    this.syncError,
  });

  final String id;
  final String ticketNumber;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String userId;
  final String userName;
  final String companyId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final TicketSyncStatus syncStatus;
  final String? syncError;

  bool get canEdit => status == TicketStatuses.waiting;

  Ticket copyWith({
    String? title,
    String? description,
    String? category,
    String? priority,
    String? status,
    DateTime? updatedAt,
    TicketSyncStatus? syncStatus,
    String? syncError,
    bool clearSyncError = false,
  }) =>
      Ticket(
        id: id,
        ticketNumber: ticketNumber,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        userId: userId,
        userName: userName,
        companyId: companyId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        resolvedAt: resolvedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        syncError: clearSyncError ? null : syncError ?? this.syncError,
      );

  factory Ticket.fromMap(String id, Map<String, dynamic> map) => Ticket(
        id: id,
        ticketNumber: map['ticketNumber'] as String? ?? ticketNumberForId(id),
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        category: map['category'] as String? ?? '',
        priority: map['priority'] as String? ?? '',
        status: map['status'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        userName: map['userName'] as String? ?? '',
        companyId: map['companyId'] as String? ?? '',
        createdAt: readFirestoreDate(map['createdAt']),
        updatedAt: readFirestoreDate(map['updatedAt']),
        resolvedAt: readFirestoreDate(map['resolvedAt']),
      );

  Map<String, dynamic> toMap() => {
        'ticketNumber': ticketNumber,
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        'status': status,
        'userId': userId,
        'userName': userName,
        'companyId': companyId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'resolvedAt': resolvedAt,
      };

  static String ticketNumberForId(String documentId) =>
      'HD-${documentId.substring(0, documentId.length < 6 ? documentId.length : 6).toUpperCase()}';
}

enum TicketSyncStatus { idle, pending, sent, failed }

String ticketNumberForId(String documentId) =>
    Ticket.ticketNumberForId(documentId);
