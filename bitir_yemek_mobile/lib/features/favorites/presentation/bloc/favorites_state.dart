part of 'favorites_bloc.dart';

abstract class FavoritesState extends Equatable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {
  const FavoritesInitial();
}

class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
}

class FavoritesLoaded extends FavoritesState {
  final List<FavoriteModel> favorites;
  final bool hasReachedMax;
  final Set<String> savedBusinessIds;

  const FavoritesLoaded({
    required this.favorites,
    required this.hasReachedMax,
    this.savedBusinessIds = const {},
  });

  @override
  List<Object?> get props => [favorites, hasReachedMax, savedBusinessIds];
}

class FavoritesLoadingMore extends FavoritesState {
  final List<FavoriteModel> favorites;
  final Set<String> savedBusinessIds;

  const FavoritesLoadingMore({
    required this.favorites,
    this.savedBusinessIds = const {},
  });

  @override
  List<Object?> get props => [favorites, savedBusinessIds];
}

class FavoritesError extends FavoritesState {
  final String message;

  const FavoritesError({required this.message});

  @override
  List<Object?> get props => [message];
}

class FavoriteRemoveSuccess extends FavoritesState {
  final String businessId;

  const FavoriteRemoveSuccess({required this.businessId});

  @override
  List<Object?> get props => [businessId];
}

class FavoriteRemoveError extends FavoritesState {
  final String message;

  const FavoriteRemoveError({required this.message});

  @override
  List<Object?> get props => [message];
}

class FavoriteAddSuccess extends FavoritesState {
  final String businessId;

  const FavoriteAddSuccess({required this.businessId});

  @override
  List<Object?> get props => [businessId];
}

class FavoriteAddError extends FavoritesState {
  final String message;

  const FavoriteAddError({required this.message});

  @override
  List<Object?> get props => [message];
}
