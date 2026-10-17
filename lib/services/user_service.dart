import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import 'firebase_error_messages.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AppUser?> getUser(String uid) async {
    final snapshot =
        await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
    final data = snapshot.data();
    return snapshot.exists && data != null ? AppUser.fromMap(uid, data) : null;
  }

  Future<String> getCompanyName(String companyId) async {
    final snapshot = await _firestore
        .collection(AppConstants.companiesCollection)
        .doc(companyId)
        .get();
    final name = snapshot.data()?['name'];
    if (!snapshot.exists || name is! String || name.trim().isEmpty) {
      throw const HelpdeskException('Data perusahaan tidak ditemukan.');
    }
    return name;
  }

  Future<void> updateProfile({
    required AppUser user,
    required String name,
    String? department,
  }) =>
      _firestore.collection(AppConstants.usersCollection).doc(user.uid).update({
        'name': name.trim(),
        if (department != null) 'department': department.trim(),
      });
}
