import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/favorite_model.dart';
import '../../domain/repositories/favorites_repository.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritesRepository _repository;
  List<FavoriteModel> _favorites = [];
  int _currentPage = 1;
  bool _hasReachedMax = false;

  FavoritesBloc({required FavoritesRepository repository})
    : _repository = repository,
      super(const FavoritesInitial()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<LoadMoreFavorites>(_onLoadMoreFavorites);
    on<RefreshFavorites>(_onRefreshFavorites);
    on<RemoveFavorite>(_onRemoveFavorite);
    on<ToggleFavorite>(_onToggleFavorite);
  }

  Set<String> get favoriteBusinessIds =>
      _favorites.map((f) => f.businessId).toSet();

  bool isFavorite(String businessId) =>
      favoriteBusinessIds.contains(businessId);

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(const FavoritesLoading());
    try {
      _currentPage = 1;
      final response = await _repository.getFavorites(page: 1);
      _favorites = response.favorites;
      _hasReachedMax = response.page >= response.totalPages;
      emit(
        FavoritesLoaded(
          favorites: _favorites,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      emit(FavoritesError(message: e.toString()));
    }
  }

  Future<void> _onLoadMoreFavorites(
    LoadMoreFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    if (_hasReachedMax) return;
    final currentState = state;
    if (currentState is! FavoritesLoaded) return;

    emit(FavoritesLoadingMore(favorites: _favorites));

    try {
      _currentPage++;
      final response = await _repository.getFavorites(page: _currentPage);
      _favorites = [..._favorites, ...response.favorites];
      _hasReachedMax = response.page >= response.totalPages;
      emit(
        FavoritesLoaded(
          favorites: _favorites,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      _currentPage--;
      emit(
        FavoritesLoaded(
          favorites: _favorites,
          hasReachedMax: _hasReachedMax,
        ),
      );
    }
  }

  Future<void> _onRefreshFavorites(
    RefreshFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      _currentPage = 1;
      final response = await _repository.getFavorites(page: 1);
      _favorites = response.favorites;
      _hasReachedMax = response.page >= response.totalPages;
      emit(
        FavoritesLoaded(
          favorites: _favorites,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      emit(FavoritesError(message: e.toString()));
    }
  }

  Future<void> _onRemoveFavorite(
    RemoveFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FavoritesLoaded) return;

    try {
      await _repository.removeFavorite(event.businessId);
      _favorites = _favorites
          .where((f) => f.businessId != event.businessId)
          .toList();

      emit(FavoriteRemoveSuccess(businessId: event.businessId));
      emit(
        FavoritesLoaded(
          favorites: _favorites,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      emit(FavoriteRemoveError(message: e.toString()));
      emit(
        FavoritesLoaded(
          favorites: _favorites,
          hasReachedMax: _hasReachedMax,
        ),
      );
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    final isFav = favoriteBusinessIds.contains(event.businessId);

    if (isFav) {
      // Remove
      try {
        await _repository.removeFavorite(event.businessId);
        _favorites = _favorites
            .where((f) => f.businessId != event.businessId)
            .toList();
        emit(FavoriteRemoveSuccess(businessId: event.businessId));
        emit(
          FavoritesLoaded(
            favorites: _favorites,
            hasReachedMax: _hasReachedMax,
          ),
        );
      } catch (e) {
        emit(FavoriteRemoveError(message: e.toString()));
        emit(
          FavoritesLoaded(
            favorites: _favorites,
            hasReachedMax: _hasReachedMax,
          ),
        );
      }
    } else {
      // Add — optimistik: kalbi anında doldur, tüm favori listesini yeniden
      // çekme. Eksik alanlar (ad/adres) Favoriler sekmesi açıldığında
      // LoadFavorites ile tam modele güncellenir. Hata olursa geri alınır.
      final placeholder = FavoriteModel(
        id: '',
        businessId: event.businessId,
        businessName: '',
        address: '',
        city: '',
        district: '',
        rating: 0,
        createdAt: DateTime.now(),
      );
      _favorites = [placeholder, ..._favorites];
      emit(FavoriteAddSuccess(businessId: event.businessId));
      emit(
        FavoritesLoaded(
          favorites: _favorites,
          hasReachedMax: _hasReachedMax,
        ),
      );

      try {
        await _repository.addFavorite(event.businessId);
        // Başarılı: placeholder yerine gerçek modeli getir (ad/adres dolu olsun).
        // Sessiz refetch — Loading emit etmiyoruz, kalp zaten optimistik dolu.
        try {
          _currentPage = 1;
          final response = await _repository.getFavorites(page: 1);
          _favorites = response.favorites;
          _hasReachedMax = response.page >= response.totalPages;
          emit(
            FavoritesLoaded(
              favorites: _favorites,
              hasReachedMax: _hasReachedMax,
            ),
          );
        } catch (_) {
          // Refetch başarısızsa optimistik (placeholder) liste kalır; sorun değil.
        }
      } catch (e) {
        // Sunucu reddetti → optimistik eklemeyi geri al.
        _favorites = _favorites
            .where((f) => f.businessId != event.businessId)
            .toList();
        emit(FavoriteAddError(message: e.toString()));
        emit(
          FavoritesLoaded(
            favorites: _favorites,
            hasReachedMax: _hasReachedMax,
          ),
        );
      }
    }
  }
}
