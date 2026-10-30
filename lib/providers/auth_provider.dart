import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firebase_error_messages.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    UserService? userService,
  })  : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService() {
    _subscription = _authService!.authStateChanges.listen(
      _handleAuthChanged,
      onError: (Object error, StackTrace stackTrace) {
        _error = 'Sesi gagal dimuat. Silakan masuk kembali.';
        _status = AuthStatus.signedOut;
        notifyListeners();
      },
    );
  }

  AuthProvider.forTesting()
      : _authService = null,
        _userService = null {
    _subscription = const Stream<User?>.empty().listen((_) {});
    _status = AuthStatus.signedOut;
  }

  final AuthService? _authService;
  final UserService? _userService;
  late final StreamSubscription<User?> _subscription;
  AuthStatus _status = AuthStatus.checking;
  AppUser? _user;
  String? _error;
  String? _infoMessage;
  String _companyName = '';
  bool _suppressAuthChanges = false;
  bool _needsVerification = false;
  bool _canResendVerification = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;
  String? get infoMessage => _infoMessage;
  String get companyName => _companyName;
  bool get needsVerification => _needsVerification;
  bool get canResendVerification => _canResendVerification;
  bool get isChecking => _status == AuthStatus.checking;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;

  Future<AppUser?> getUserProfile(String uid) => _userService!.getUser(uid);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearInfo() {
    if (_infoMessage == null) return;
    _infoMessage = null;
    notifyListeners();
  }

  Future<void> _handleAuthChanged(User? firebaseUser) async {
    if (_suppressAuthChanges) return;
    if (firebaseUser == null) {
      _user = null;
      _companyName = '';
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    if (_user?.uid == firebaseUser.uid && _status == AuthStatus.signedIn) {
      return;
    }
    await _loadUser(firebaseUser.uid);
  }

  Future<void> _loadUser(String uid) async {
    _status = AuthStatus.checking;
    notifyListeners();
    try {
      final profile = await _userService!.getUser(uid);
      if (profile == null ||
          profile.status != AccountStatuses.active ||
          !UserRoles.all.contains(profile.role)) {
        await _authService!.signOut();
        _user = null;
        _status = AuthStatus.signedOut;
        _error = profile == null
            ? 'Profil pengguna tidak ditemukan.'
            : 'Akun atau role pengguna tidak valid.';
      } else {
        _user = profile;
        _companyName = await _userService.getCompanyName(profile.companyId);
        _status = AuthStatus.signedIn;
        _error = null;
      }
    } on FirebaseException catch (exception) {
      _status = AuthStatus.signedOut;
      _error = firestoreErrorMessage(exception);
      await _authService!.signOut();
    } on HelpdeskException catch (exception) {
      _status = AuthStatus.signedOut;
      _error = exception.message;
      await _authService!.signOut();
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    // LoginCubit tracks the in-flight request; keep the login route active.
    _error = null;
    _needsVerification = false;
    _canResendVerification = false;
    _suppressAuthChanges = true;
    notifyListeners();
    try {
      final profile = await _authService!.signIn(email, password);
      _user = profile;
      _companyName = await _userService!.getCompanyName(profile.companyId);
      _status = AuthStatus.signedIn;
      notifyListeners();
      return true;
    } on HelpdeskException catch (exception) {
      _status = AuthStatus.signedOut;
      _error = exception.message;
      _needsVerification = exception is EmailNotVerifiedException;
      _canResendVerification = _needsVerification;
      await _authService!.signOut();
    } on FirebaseException catch (exception) {
      _status = AuthStatus.signedOut;
      _error = firestoreErrorMessage(exception);
      await _authService!.signOut();
    } finally {
      _suppressAuthChanges = false;
    }
    notifyListeners();
    return false;
  }

  Future<bool> registerEmployee({
    required String name,
    required String email,
    required String password,
    required String department,
    required String companyCode,
  }) async {
    _user = null;
    _companyName = '';
    _error = null;
    _infoMessage = null;
    _canResendVerification = false;
    _suppressAuthChanges = true;
    notifyListeners();
    try {
      final result = await _authService!.registerEmployee(
        name: name,
        email: email,
        password: password,
        department: department,
        companyCode: companyCode,
      );
      _user = null;
      _companyName = '';
      _status = AuthStatus.signedOut;
      _canResendVerification = !result.verificationSent;
      _infoMessage = result.verificationSent
          ? 'Akun dibuat. Kami mengirim email verifikasi ke ${result.employee.email}. '
              'Buka email tersebut (cek juga folder Spam), lalu masuk.'
          : 'Akun dibuat, tetapi email verifikasi belum dapat dikirim. '
              'Masuk dengan email dan password lalu pilih "Kirim ulang email verifikasi".';
      notifyListeners();
      return true;
    } on HelpdeskException catch (exception) {
      _status = AuthStatus.signedOut;
      _error = exception.message;
      await _authService!.signOut();
    } on FirebaseException catch (exception) {
      _status = AuthStatus.signedOut;
      _error = firestoreErrorMessage(exception);
      await _authService!.signOut();
    } finally {
      _suppressAuthChanges = false;
    }
    notifyListeners();
    return false;
  }

  Future<bool> resendVerification(String email, String password) async {
    _error = null;
    _needsVerification = false;
    _suppressAuthChanges = true;
    notifyListeners();
    try {
      await _authService!.resendVerification(email, password);
      _canResendVerification = false;
      return true;
    } on HelpdeskException catch (exception) {
      _error = exception.message;
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
    } finally {
      _suppressAuthChanges = false;
    }
    notifyListeners();
    return false;
  }

  Future<bool> sendPasswordReset(String email) async {
    _error = null;
    try {
      await _authService!.sendPasswordReset(email);
      return true;
    } on HelpdeskException catch (exception) {
      _error = exception.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? department,
  }) async {
    final currentUser = _user;
    if (currentUser == null) return false;
    _error = null;
    try {
      await _userService!.updateProfile(
        user: currentUser,
        name: name,
        department: department,
      );
      _user = currentUser.copyWith(
        name: name.trim(),
        department: department?.trim(),
      );
      notifyListeners();
      return true;
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService!.signOut();
    _user = null;
    _status = AuthStatus.signedOut;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

enum AuthStatus { checking, signedOut, signedIn }
