part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Emitted after a login code has been sent to [email].
/// [isNewUser] tells the UI whether to collect a name for a new account.
class OtpSent extends AuthState {
  final String email;
  final bool isNewUser;
  final String message;

  const OtpSent({
    required this.email,
    required this.isNewUser,
    required this.message,
  });

  @override
  List<Object?> get props => [email, isNewUser, message];
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
