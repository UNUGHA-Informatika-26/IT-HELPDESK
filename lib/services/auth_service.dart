import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import 'firebase_error_messages.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  Future<AppUser> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final credentialUser = result.user;
      if (credentialUser == null) {
        throw const HelpdeskException('Profil pengguna tidak ditemukan.');
      }
      final user = await getProfile(credentialUser.uid);
      if (user == null) {
        await _auth.signOut();
        throw const HelpdeskException('Profil pengguna tidak ditemukan.');
      }
      if (user.status != AccountStatuses.active) {
        await _auth.signOut();
        throw const HelpdeskException(
          'Akun Anda tidak aktif. Hubungi administrator.',
        );
      }
      if (!UserRoles.all.contains(user.role)) {
        await _auth.signOut();
        throw const HelpdeskException('Profil pengguna tidak valid.');
      }
      if (mustVerifyEmail(
        role: user.role,
        creationTime: credentialUser.metadata.creationTime,
      )) {
        await credentialUser.reload();
        if (!(_auth.currentUser ?? credentialUser).emailVerified) {
          await _auth.signOut();
          throw const EmailNotVerifiedException();
        }
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw HelpdeskException(authErrorMessage(error));
    } on FirebaseException catch (error) {
      await _auth.signOut();
      throw HelpdeskException(firestoreErrorMessage(error));
    }
  }

  Future<AppUser?> getProfile(String uid) async {
    final snapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    final data = snapshot.data();
    return snapshot.exists && data != null ? AppUser.fromMap(uid, data) : null;
  }

  Future<RegistrationResult> registerEmployee({
    required String name,
    required String email,
    required String password,
    required String department,
    required String companyCode,
  }) async {
    try {
      final normalizedCode = companyCode.trim().toUpperCase();
      final codeSnapshot = await _firestore
          .collection(AppConstants.companyCodesCollection)
          .doc(normalizedCode)
          .get();
      final codeData = codeSnapshot.data();
      if (!codeSnapshot.exists ||
          codeData?['active'] != true ||
          codeData?['companyId'] is! String) {
        throw const HelpdeskException(
          'Kode perusahaan salah atau sudah tidak aktif.',
        );
      }

      final companyId = codeData!['companyId'] as String;
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final authUser = credential.user;
      if (authUser == null) {
        throw const HelpdeskException('Akun tidak berhasil dibuat.');
      }

      final employee = AppUser(
        uid: authUser.uid,
        name: name.trim(),
        email: email.trim(),
        role: UserRoles.employee,
        companyId: companyId,
        companyCode: normalizedCode,
        status: AccountStatuses.active,
        department: department.trim(),
      );
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(authUser.uid)
            .set({
          ...employee.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        await authUser.delete();
        rethrow;
      }
      var verificationSent = true;
      try {
        await authUser.sendEmailVerification();
      } on FirebaseAuthException {
        verificationSent = false;
      } finally {
        await _auth.signOut();
      }
      return RegistrationResult(
        employee: employee,
        verificationSent: verificationSent,
      );
    } on FirebaseAuthException catch (error) {
      throw HelpdeskException(authErrorMessage(error));
    } on FirebaseException catch (error) {
      throw HelpdeskException(firestoreErrorMessage(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw HelpdeskException(authErrorMessage(error));
    }
  }

  Future<void> resendVerification(String email, String password) async {
    var signedIn = false;
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      signedIn = true;
      final user = result.user;
      if (user == null) {
        throw const HelpdeskException('Profil pengguna tidak ditemukan.');
      }
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw HelpdeskException(authErrorMessage(error));
    } finally {
      if (signedIn) await _auth.signOut();
    }
  }

  Future<void> signOut() => _auth.signOut();
}

bool requiresEmailVerification(DateTime? creationTime) =>
    creationTime?.isAfter(AppConstants.emailVerificationEnforcedFrom) ?? false;

bool mustVerifyEmail({
  required String role,
  required DateTime? creationTime,
}) =>
    role == UserRoles.employee && requiresEmailVerification(creationTime);

class RegistrationResult {
  const RegistrationResult({
    required this.employee,
    required this.verificationSent,
  });

  final AppUser employee;
  final bool verificationSent;
}

class EmailNotVerifiedException extends HelpdeskException {
  const EmailNotVerifiedException()
      : super(
          'Email belum diverifikasi. Periksa kotak masuk atau Spam, atau '
          'kirim ulang email verifikasi.',
        );
}
