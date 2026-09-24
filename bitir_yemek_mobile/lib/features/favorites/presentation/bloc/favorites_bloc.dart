import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/favorite_model.dart';
import '../../domain/repositories/favorites_repository.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritesRepository _repository;
  final DateTime Function() _now;
  // Keep saved relationships independently of the currently available cards.
  List<FavoriteModel> _favorites = [];
  int _currentPage = 1;
  bool _hasReachedMax = false;
  bool _hasLoaded = false;
  bool _busy = false;
  bool _refreshQueued = false;
  static const _pageSize = 10;

  FavoritesBloc({
    required FavoritesRepository repository,
    DateTime Function()? now,
  }) : _repository = repository,
       _now = now ?? DateTime.now,
       super(const FavoritesInitial()) {
    // One queue across event types: a late list response must not undo a
    // completed mutation, and rapid toggles must follow the user's order.
    on<FavoritesEvent>((event, emit) async {
      _busy = true;
      try {
        if (event is LoadFavorites) await _onLoadFavorites(event, emit);
        if (event is LoadMoreFavorites) await _onLoadMoreFavorites(event, emit);
        if (event is RefreshFavorites) await _onRefreshFavorites(event, emit);
        if (event is RemoveFavorite) {
          await _removeFavorite(event.businessId, emit);
        }
        if (event is ToggleFavorite) await _onToggleFavorite(event, emit);
      } finally {
        _busy = false;
        if (event is RefreshFavorites) {
          _refreshQueued = false;
          event.onDone?.complete();
        }
      }
    }, transformer: sequential());
  }

  Set<String> get favoriteBusinessIds =>
      _favorites.map((favorite) => favorite.businessId).toSet();

  bool isFavorite(String businessId) =>
      favoriteBusinessIds.contains(businessId);

  /// Called on tab entry, foreground resume and the visible catalog timer.
  /// Slow requests and mutations share one queue without accumulating polls.
  void refreshCurrent() {
    if (isClosed ||
        state is FavoritesInitial ||
        state is FavoritesLoading ||
        _busy ||
        _refreshQueued) {
      return;
    }
    _refreshQueued = true;
    add(const RefreshFavorites(background: true));
  }

  List<FavoriteModel> _available(List<FavoriteModel> favorites) {
    final now = _now();
    return favorites
        .where((favorite) => favorite.hasAvailablePackage(now: now))
        .toList();
  }

  void _emitLoaded(Emitter<FavoritesState> emit) {
    emit(
      FavoritesLoaded(
        favorites: _available(_favorites),
        savedBusinessIds: favoriteBusinessIds,
        hasReachedMax: _hasReachedMax,
      ),
    );
  }

  Future<void> _fetchPages({
    required int startPage,
    required bool forceRefresh,
    int minimumPage = 1,
  }) async {
    final fetched = <String, FavoriteModel>{};
    var page = startPage;
    var reachedMax = false;
    do {
      final response = await _repository.getFavorites(
        page: page,
        limit: _pageSize,
        forceRefresh: forceRefresh,
      );
      for (final favorite in response.favorites) {
        fetched[favorite.businessId] = favorite;
      }
      reachedMax = page >= response.totalPages;
      // Hidden rows still occupy server pages. Fill a visible page (or reach
      // the end) so an empty/short first page cannot strand later favorites.
      if (reachedMax ||
          (page >= minimumPage &&
              _available(fetched.values.toList()).length >= _pageSize)) {
        break;
      }
      page++;
    } while (true);

    final combined = <String, FavoriteModel>{
      if (startPage > 1)
        for (final favorite in _favorites) favorite.businessId: favorite,
      ...fetched,
    };
    _favorites = combined.values.toList();
    _currentPage = page;
    _hasReachedMax = reachedMax;
    _hasLoaded = true;
  }

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(const FavoritesLoading());
    try {
      await _fetchPages(startPage: 1, forceRefresh: false);
      _emitLoaded(emit);
    } catch (e) {
      emit(FavoritesError(message: e.toString()));
    }
  }

  Future<void> _onLoadMoreFavorites(
    LoadMoreFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    if (_hasReachedMax || state is! FavoritesLoaded) return;
    emit(
      FavoritesLoadingMore(
        favorites: _available(_favorites),
        savedBusinessIds: favoriteBusinessIds,
      ),
    );
    try {
      await _fetchPages(startPage: _currentPage + 1, forceRefresh: false);
    } catch (_) {
      // Keep pagination and cards intact; another scroll can retry this page.
    }
    _emitLoaded(emit);
  }

  Future<void> _onRefreshFavorites(
    RefreshFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    // Apply the clock before awaiting the network, even when offline.
    if (_hasLoaded) _emitLoaded(emit);
    try {
      await _fetchPages(
        startPage: 1,
        minimumPage: _currentPage,
        forceRefresh: true,
      );
      _emitLoaded(emit);
    } catch (e) {
      if (event.background && _hasLoaded) {
        _emitLoaded(emit);
      } else {
        emit(FavoritesError(message: e.toString()));
      }
    }
  }

  Future<void> _removeFavorite(
    String businessId,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      await _repository.removeFavorite(businessId);
      _favorites = _favorites
          .where((favorite) => favorite.businessId != businessId)
          .toList();
      emit(FavoriteRemoveSuccess(businessId: businessId));
    } catch (e) {
      emit(FavoriteRemoveError(message: e.toString()));
    }
    _emitLoaded(emit);
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    if (isFavorite(event.businessId)) {
      await _removeFavorite(event.businessId, emit);
      return;
    }

    // Fill the heart immediately. A placeholder has no available package and
    // does not produce an empty card while the full relationship is fetched.
    final placeholder = FavoriteModel(
      id: '',
      businessId: event.businessId,
      businessName: '',
      address: '',
      city: '',
      district: '',
      rating: 0,
      createdAt: _now(),
    );
    _favorites = [placeholder, ..._favorites];
    emit(FavoriteAddSuccess(businessId: event.businessId));
    _emitLoaded(emit);
    try {
      await _repository.addFavorite(event.businessId);
      try {
        await _fetchPages(
          startPage: 1,
          minimumPage: _currentPage,
          forceRefresh: true,
        );
        _emitLoaded(emit);
      } catch (_) {
        // Keep the saved heart if refreshing its card fails.
      }
    } catch (e) {
      _favorites = _favorites
          .where((favorite) => favorite.businessId != event.businessId)
          .toList();
      emit(FavoriteAddError(message: e.toString()));
      _emitLoaded(emit);
    }
  }
}
