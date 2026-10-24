import 'app_user.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.type,
    required this.ticketNumber,
    required this.ticketTitle,
    required this.reason,
    required this.adminName,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String companyId;
  final String type;
  final String ticketNumber;
  final String ticketTitle;
  final String reason;
  final String adminName;
  final DateTime? createdAt;
  final bool read;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        userId: map['userId'] as String? ?? '',
        companyId: map['companyId'] as String? ?? '',
        type: map['type'] as String? ?? '',
        ticketNumber: map['ticketNumber'] as String? ?? '',
        ticketTitle: map['ticketTitle'] as String? ?? '',
        reason: map['reason'] as String? ?? '',
        adminName: map['adminName'] as String? ?? '',
        createdAt: readFirestoreDate(map['createdAt']),
        read: map['read'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'companyId': companyId,
        'type': type,
        'ticketNumber': ticketNumber,
        'ticketTitle': ticketTitle,
        'reason': reason,
        'adminName': adminName,
        'createdAt': createdAt,
        'read': read,
      };
}
