import 'app_user.dart';

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.status,
    this.ownerUid,
    this.createdAt,
  });

  final String id;
  final String name;
  final String status;
  final String? ownerUid;
  final DateTime? createdAt;

  factory Company.fromMap(String id, Map<String, dynamic> map) => Company(
        id: id,
        name: map['name'] as String? ?? '',
        status: map['status'] as String? ?? '',
        ownerUid: map['ownerUid'] as String?,
        createdAt: readFirestoreDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'status': status,
        'ownerUid': ownerUid,
        'createdAt': createdAt,
      };
}
