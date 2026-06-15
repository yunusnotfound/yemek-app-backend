part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class OtpRequested extends AuthEvent {
  final String email;

  const OtpRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class OtpVerifyRequested extends AuthEvent {
  final String email;
  final String code;
  final String? name;
  final String? phone;

  const OtpVerifyRequested({
    required this.email,
    required this.code,
    this.name,
    this.phone,
  });

  @override
  List<Object?> get props => [email, code, name, phone];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

class GoogleSignInRequested extends AuthEvent {
  final String role;

  const GoogleSignInRequested({this.role = 'customer'});

  @override
  List<Object?> get props => [role];
}

class AppleSignInRequested extends AuthEvent {
  final String role;

  const AppleSignInRequested({this.role = 'customer'});

  @override
  List<Object?> get props => [role];
}

