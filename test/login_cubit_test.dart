import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/features/auth/cubit/login_cubit.dart';
import 'package:it_helpdesk_flutter/features/auth/cubit/login_state.dart';
import 'package:it_helpdesk_flutter/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider authProvider;

  setUp(() {
    authProvider = MockAuthProvider();
  });

  blocTest<LoginCubit, LoginState>(
    'emits LoginFailure with an email error when email is empty',
    build: () => LoginCubit(authProvider),
    act: (cubit) => cubit.login('', 'password123'),
    expect: () => [
      const LoginFailure(message: '', emailError: 'Email wajib diisi.'),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'emits LoginFailure with a password error when password is too short',
    build: () => LoginCubit(authProvider),
    act: (cubit) => cubit.login('ayu@example.com', 'short'),
    expect: () => [
      const LoginFailure(
        message: '',
        passwordError: 'Password minimal 8 karakter.',
      ),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'emits loading and success when sign-in succeeds',
    build: () {
      when(() => authProvider.signIn('ayu@example.com', 'password123'))
          .thenAnswer((_) async => true);
      return LoginCubit(authProvider);
    },
    act: (cubit) => cubit.login('ayu@example.com', 'password123'),
    expect: () => [const LoginLoading(), const LoginSuccess()],
  );

  blocTest<LoginCubit, LoginState>(
    'emits loading and failure with the provider error when sign-in fails',
    build: () {
      when(() => authProvider.signIn('ayu@example.com', 'password123'))
          .thenAnswer((_) async => false);
      when(() => authProvider.error).thenReturn('Password salah.');
      when(() => authProvider.needsVerification).thenReturn(false);
      return LoginCubit(authProvider);
    },
    act: (cubit) => cubit.login('ayu@example.com', 'password123'),
    expect: () => [
      const LoginLoading(),
      const LoginFailure(message: 'Password salah.'),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'marks login failure when email verification is required',
    build: () {
      when(() => authProvider.signIn('ayu@example.com', 'password123'))
          .thenAnswer((_) async => false);
      when(() => authProvider.error).thenReturn(
        'Email belum diverifikasi. Periksa kotak masuk atau Spam, atau '
        'kirim ulang email verifikasi.',
      );
      when(() => authProvider.needsVerification).thenReturn(true);
      return LoginCubit(authProvider);
    },
    act: (cubit) => cubit.login('ayu@example.com', 'password123'),
    expect: () => [
      const LoginLoading(),
      const LoginFailure(
        message:
            'Email belum diverifikasi. Periksa kotak masuk atau Spam, atau '
            'kirim ulang email verifikasi.',
        needsVerification: true,
      ),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'emits info after verification email is resent',
    build: () {
      when(
        () => authProvider.resendVerification('ayu@example.com', 'password123'),
      ).thenAnswer((_) async => true);
      return LoginCubit(authProvider);
    },
    act: (cubit) => cubit.resendVerification('ayu@example.com', 'password123'),
    expect: () => [
      const LoginLoading(),
      const LoginInfo(
        message: 'Email verifikasi berhasil dikirim ulang. Periksa kotak '
            'masuk atau folder Spam.',
      ),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'emits failure when verification email resend fails',
    build: () {
      when(
        () => authProvider.resendVerification('ayu@example.com', 'password123'),
      ).thenAnswer((_) async => false);
      when(() => authProvider.error).thenReturn(
        'Terlalu sering meminta email. Coba lagi beberapa menit lagi.',
      );
      return LoginCubit(authProvider);
    },
    act: (cubit) => cubit.resendVerification('ayu@example.com', 'password123'),
    expect: () => [
      const LoginLoading(),
      const LoginFailure(
        message: 'Terlalu sering meminta email. Coba lagi beberapa menit lagi.',
      ),
    ],
  );
}
