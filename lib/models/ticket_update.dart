import 'app_user.dart';

class TicketUpdate {
  const TicketUpdate({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.oldStatus,
    required this.newStatus,
    required this.note,
    this.createdAt,
  });

  final String id;
  final String adminId;
  final String adminName;
  final String oldStatus;
  final String newStatus;
  final String note;
  final DateTime? createdAt;

  factory TicketUpdate.fromMap(String id, Map<String, dynamic> map) =>
      TicketUpdate(
        id: id,
        adminId: map['adminId'] as String? ?? '',
        adminName: map['adminName'] as String? ?? '',
        oldStatus: map['oldStatus'] as String? ?? '',
        newStatus: map['newStatus'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdAt: readFirestoreDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'adminId': adminId,
        'adminName': adminName,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'note': note,
        'createdAt': createdAt,
      };
}
