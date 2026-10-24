import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/form_validators.dart';
import '../../../providers/auth_provider.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._authProvider) : super(const LoginInitial());

  final AuthProvider _authProvider;

  Future<void> login(String email, String password) async {
    final emailError = FormValidators.email(email);
    final passwordError = FormValidators.password(password);
    if (emailError != null || passwordError != null) {
      emit(
        LoginFailure(
          message: '',
          emailError: emailError,
          passwordError: passwordError,
        ),
      );
      return;
    }

    emit(const LoginLoading());
    final ok = await _authProvider.signIn(email, password);
    if (isClosed) return;
    if (ok) {
      emit(const LoginSuccess());
    } else {
      emit(
        LoginFailure(
          message: _authProvider.error ?? 'Gagal masuk. Silakan coba lagi.',
        ),
      );
    }
  }

  void reset() => emit(const LoginInitial());
}
