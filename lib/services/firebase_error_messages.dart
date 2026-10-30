import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(FirebaseAuthException error) => switch (error.code) {
      'invalid-email' => 'Format email tidak valid.',
      'user-disabled' => 'Akun Anda tidak aktif. Hubungi administrator.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Email atau password salah.',
      'email-already-in-use' => 'Email sudah digunakan.',
      'weak-password' => 'Password minimal 8 karakter.',
      'network-request-failed' =>
        'Koneksi internet bermasalah. Periksa koneksi lalu coba lagi.',
      'too-many-requests' =>
        'Terlalu sering meminta email. Coba lagi beberapa menit lagi.',
      _ => 'Autentikasi gagal. Silakan coba lagi.',
    };

String firestoreErrorMessage(FirebaseException error) => switch (error.code) {
      'permission-denied' => 'Akses ditolak oleh aturan keamanan Firestore.',
      'unavailable' ||
      'deadline-exceeded' =>
        'Koneksi bermasalah. Periksa internet lalu coba lagi.',
      'not-found' => 'Data tidak ditemukan.',
      _ => 'Data gagal dimuat atau disimpan. Silakan coba lagi.',
    };

class HelpdeskException implements Exception {
  const HelpdeskException(this.message);

  final String message;

  @override
  String toString() => message;
}
