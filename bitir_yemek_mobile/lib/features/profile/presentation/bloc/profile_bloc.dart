import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/repositories/profile_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;
  int _generation = 0;
  bool _loggingOut = false;
  bool get _sessionEnded =>
      state is ProfileLoggedOut || state is AccountDeleted;

  ProfileBloc({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
    on<ProfileLogoutRequested>(_onLogoutRequested);
    on<DeleteAccountRequested>(_onDeleteAccount);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    if (_loggingOut ||
        _sessionEnded ||
        state is AccountDeleting ||
        state is ProfileLoading ||
        state is ProfileUpdating) {
      return;
    }
    final generation = ++_generation;
    emit(ProfileLoading());

    final result = await _profileRepository.getProfile();
    if (emit.isDone || generation != _generation) return;

    if (result.isSuccess) {
      emit(ProfileLoaded(user: result.user!));
    } else {
      emit(ProfileError(message: result.error!));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded && !_loggingOut) {
      final generation = ++_generation;
      emit(ProfileUpdating(user: currentState.user));

      final result = await _profileRepository.updateProfile(
        name: event.name,
        phone: event.phone,
      );
      if (emit.isDone || generation != _generation) return;

      if (result.isSuccess) {
        emit(
          ProfileUpdateSuccess(
            user: result.user!,
            message: result.message ?? 'Profil guncellendi',
          ),
        );
        emit(ProfileLoaded(user: result.user!));
      } else {
        emit(
          ProfileUpdateError(user: currentState.user, message: result.error!),
        );
        emit(ProfileLoaded(user: currentState.user));
      }
    }
  }

  Future<void> _onLogoutRequested(
    ProfileLogoutRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (_loggingOut || _sessionEnded || state is AccountDeleting) return;
    _loggingOut = true;
    ++_generation;
    try {
      await _profileRepository.logout();
      if (!emit.isDone) emit(ProfileLoggedOut());
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> _onDeleteAccount(
    DeleteAccountRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded || _loggingOut) return;
    final generation = ++_generation;
    emit(AccountDeleting(user: currentState.user));

    final result = await _profileRepository.deleteAccount();
    if (emit.isDone || generation != _generation) return;

    if (result.isSuccess) {
      emit(AccountDeleted());
    } else {
      emit(
        AccountDeleteError(
          user: currentState.user,
          message: result.error ?? 'Hesap silinemedi',
        ),
      );
      emit(ProfileLoaded(user: currentState.user));
    }
  }
}
