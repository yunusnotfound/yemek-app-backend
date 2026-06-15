import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthInitial()) {
    on<OtpRequested>(_onOtpRequested);
    on<OtpVerifyRequested>(_onOtpVerifyRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<AppleSignInRequested>(_onAppleSignInRequested);
  }

  Future<void> _onOtpRequested(
    OtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.requestOtp(event.email);

    if (result.isSuccess) {
      emit(
        OtpSent(
          email: event.email,
          isNewUser: result.isNewUser,
          message: result.message ?? 'Giriş kodu gönderildi',
        ),
      );
    } else {
      emit(AuthError(message: result.error!));
    }
  }

  Future<void> _onOtpVerifyRequested(
    OtpVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.verifyOtp(
      email: event.email,
      code: event.code,
      name: event.name,
      phone: event.phone,
    );

    if (result.isSuccess) {
      emit(AuthAuthenticated(user: result.user!));
    } else {
      emit(AuthError(message: result.error!));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final isLoggedIn = await _authRepository.isLoggedIn();

    if (isLoggedIn) {
      // User has token, load user data from storage
      final userData = await _authRepository.getCurrentUser();
      if (userData != null) {
        emit(AuthAuthenticated(user: userData));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.googleLogin(role: event.role);

    if (result.isSuccess) {
      emit(AuthAuthenticated(user: result.user!));
    } else {
      emit(AuthError(message: result.error!));
    }
  }

  Future<void> _onAppleSignInRequested(
    AppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.appleLogin(role: event.role);

    if (result.isSuccess) {
      emit(AuthAuthenticated(user: result.user!));
    } else {
      emit(AuthError(message: result.error!));
    }
  }
}
