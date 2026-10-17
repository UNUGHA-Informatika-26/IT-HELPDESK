import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.companyId,
    required this.companyCode,
    required this.status,
    required this.department,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String companyId;
  final String companyCode;
  final String status;
  final String department;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRoles.admin;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        role: map['role'] as String? ?? '',
        companyId: map['companyId'] as String? ?? '',
        companyCode: map['companyCode'] as String? ?? '',
        status: map['status'] as String? ?? '',
        department: map['department'] as String? ?? '',
        createdAt: _readDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'companyId': companyId,
        'companyCode': companyCode,
        'status': status,
        'department': department,
        'createdAt': createdAt,
      };

  AppUser copyWith({
    String? name,
    String? department,
  }) =>
      AppUser(
        uid: uid,
        name: name ?? this.name,
        email: email,
        role: role,
        companyId: companyId,
        companyCode: companyCode,
        status: status,
        department: department ?? this.department,
        createdAt: createdAt,
      );
}

DateTime? readFirestoreDate(Object? value) => _readDate(value);

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
