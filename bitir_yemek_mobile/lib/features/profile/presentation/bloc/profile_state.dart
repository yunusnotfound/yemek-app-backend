part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserModel user;

  const ProfileLoaded({required this.user});

  @override
  List<Object?> get props => [user];
}

class ProfileUpdating extends ProfileState {
  final UserModel user;

  const ProfileUpdating({required this.user});

  @override
  List<Object?> get props => [user];
}

class ProfileUpdateSuccess extends ProfileState {
  final UserModel user;
  final String message;

  const ProfileUpdateSuccess({required this.user, required this.message});

  @override
  List<Object?> get props => [user, message];
}

class ProfileUpdateError extends ProfileState {
  final UserModel user;
  final String message;

  const ProfileUpdateError({required this.user, required this.message});

  @override
  List<Object?> get props => [user, message];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError({required this.message});

  @override
  List<Object?> get props => [message];
}

class ProfileLoggedOut extends ProfileState {}

class AccountDeleting extends ProfileState {
  final UserModel user;

  const AccountDeleting({required this.user});

  @override
  List<Object?> get props => [user];
}

class AccountDeleted extends ProfileState {}

class AccountDeleteError extends ProfileState {
  final UserModel user;
  final String message;

  const AccountDeleteError({required this.user, required this.message});

  @override
  List<Object?> get props => [user, message];
}
