sealed class LoginState {
  const LoginState();

  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is LoginState &&
          _listEquals(props, other.props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(props));
}

final class LoginInitial extends LoginState {
  const LoginInitial();

  @override
  List<Object?> get props => const [];
}

final class LoginLoading extends LoginState {
  const LoginLoading();

  @override
  List<Object?> get props => const [];
}

final class LoginSuccess extends LoginState {
  const LoginSuccess();

  @override
  List<Object?> get props => const [];
}

final class LoginFailure extends LoginState {
  const LoginFailure({
    required this.message,
    this.emailError,
    this.passwordError,
    this.needsVerification = false,
  });

  final String message;
  final String? emailError;
  final String? passwordError;
  final bool needsVerification;

  @override
  List<Object?> get props =>
      [message, emailError, passwordError, needsVerification];
}

final class LoginInfo extends LoginState {
  const LoginInfo({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

bool _listEquals(List<Object?> first, List<Object?> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
