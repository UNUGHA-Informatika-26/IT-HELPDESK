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
      return LoginCubit(authProvider);
    },
    act: (cubit) => cubit.login('ayu@example.com', 'password123'),
    expect: () => [
      const LoginLoading(),
      const LoginFailure(message: 'Password salah.'),
    ],
  );
}
