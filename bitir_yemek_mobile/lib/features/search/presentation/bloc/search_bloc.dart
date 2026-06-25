import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:stream_transform/stream_transform.dart';
import '../../../home/data/models/package_model.dart';
import '../../../home/domain/repositories/businesses_repository.dart';

part 'search_event.dart';
part 'search_state.dart';

/// Debounce duration for search queries — prevents firing a request on
/// every keystroke; waits until the user pauses typing for 400ms.
const _kSearchDebounce = Duration(milliseconds: 400);

/// Combined transformer: debounce + restartable.
/// Any in-flight search is cancelled when a new query arrives after the
/// debounce window, keeping only the latest query active.
EventTransformer<E> _debouncedRestartable<E>(Duration duration) {
  return (events, mapper) =>
      restartable<E>().call(events.debounce(duration), mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final BusinessesRepository _repository;

  SearchBloc({required BusinessesRepository repository})
    : _repository = repository,
      super(SearchInitial()) {
    // SearchPackages uses debounced+restartable: previous request is cancelled
    // if a new search query arrives within the debounce window.
    on<SearchPackages>(
      _onSearchPackages,
      transformer: _debouncedRestartable(_kSearchDebounce),
    );
    on<LoadMoreSearchResults>(_onLoadMoreSearchResults);
    on<UpdateSortOrder>(_onUpdateSortOrder);
    on<UpdateSearchFilters>(_onUpdateSearchFilters);
  }

  Future<void> _onSearchPackages(
    SearchPackages event,
    Emitter<SearchState> emit,
  ) async {
    // Pull-to-refresh sırasında mevcut liste görünür kalsın (shimmer'a düşmesin).
    if (!event.forceRefresh) {
      emit(SearchLoading());
    }

    try {
      final result = await _repository.getNearbyPackages(
        latitude: event.latitude,
        longitude: event.longitude,
        radius: 50.0, // Daha geniş arama
        page: 1,
        limit: 20,
        forceRefresh: event.forceRefresh,
      );

      if (result.isSuccess) {
        var packages = result.packages!;
        // Cache the lowercased query once to avoid repeated allocations
        // inside the filter loop.
        if (event.query != null && event.query!.isNotEmpty) {
          final query = event.query!.toLowerCase();
          packages = packages.where((p) {
            return p.title.toLowerCase().contains(query) ||
                p.business.name.toLowerCase().contains(query) ||
                (p.description?.toLowerCase().contains(query) ?? false) ||
                p.business.category.name.toLowerCase().contains(query);
          }).toList();
        }
        final sortedPackages = _sortPackages(packages, event.sortOrder);
        emit(
          SearchLoaded(
            packages: sortedPackages,
            sortOrder: event.sortOrder,
            hasReachedMax:
                result.pagination!.page >= result.pagination!.totalPages,
            currentPage: 1,
          ),
        );
      } else {
        emit(SearchError(message: result.error!));
      }
    } catch (e) {
      emit(SearchError(message: 'Arama yapılırken hata oluştu: $e'));
    }
  }

  Future<void> _onLoadMoreSearchResults(
    LoadMoreSearchResults event,
    Emitter<SearchState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SearchLoaded || currentState.hasReachedMax) return;

    emit(
      SearchLoadingMore(
        packages: currentState.packages,
        sortOrder: currentState.sortOrder,
      ),
    );

    try {
      final result = await _repository.getNearbyPackages(
        latitude: event.latitude,
        longitude: event.longitude,
        radius: 50.0,
        page: currentState.currentPage + 1,
        limit: 20,
      );

      if (result.isSuccess) {
        final allPackages = [...currentState.packages, ...result.packages!];
        final sortedPackages = _sortPackages(
          allPackages,
          currentState.sortOrder,
        );

        emit(
          SearchLoaded(
            packages: sortedPackages,
            sortOrder: currentState.sortOrder,
            hasReachedMax:
                result.pagination!.page >= result.pagination!.totalPages,
            currentPage: currentState.currentPage + 1,
          ),
        );
      }
    } catch (e) {
      emit(SearchError(message: 'Daha fazla yüklenirken hata oluştu: $e'));
    }
  }

  void _onUpdateSortOrder(UpdateSortOrder event, Emitter<SearchState> emit) {
    final currentState = state;
    if (currentState is! SearchLoaded) return;

    final sortedPackages = _sortPackages(
      currentState.packages,
      event.sortOrder,
    );
    emit(
      currentState.copyWith(
        packages: sortedPackages,
        sortOrder: event.sortOrder,
      ),
    );
  }

  void _onUpdateSearchFilters(
    UpdateSearchFilters event,
    Emitter<SearchState> emit,
  ) {
    // Filtreleme mantığı buraya eklenecek
  }

  List<PackageModel> _sortPackages(
    List<PackageModel> packages,
    SortOrder sortOrder,
  ) {
    final sorted = List<PackageModel>.from(packages);

    switch (sortOrder) {
      case SortOrder.priceAsc:
        sorted.sort((a, b) => a.discountedPrice.compareTo(b.discountedPrice));
        break;
      case SortOrder.priceDesc:
        sorted.sort((a, b) => b.discountedPrice.compareTo(a.discountedPrice));
        break;
      case SortOrder.distance:
        sorted.sort((a, b) {
          final distA = a.business.distance ?? double.infinity;
          final distB = b.business.distance ?? double.infinity;
          return distA.compareTo(distB);
        });
        break;
      case SortOrder.rating:
        sorted.sort((a, b) => b.business.rating.compareTo(a.business.rating));
        break;
      case SortOrder.discount:
        sorted.sort(
          (a, b) => b.discountPercentage.compareTo(a.discountPercentage),
        );
        break;
    }

    return sorted;
  }
}
