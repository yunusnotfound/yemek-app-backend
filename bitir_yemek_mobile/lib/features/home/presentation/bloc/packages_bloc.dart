import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/business_model.dart';
import '../../data/models/package_model.dart';
import '../../domain/repositories/businesses_repository.dart';

part 'packages_event.dart';
part 'packages_state.dart';

class PackagesBloc extends Bloc<PackagesEvent, PackagesState> {
  final BusinessesRepository _repository;

  /// Seçili kategori (null = "Hepsi"). Liste konuma duyarlı kalır; kategori
  /// filtresi yakındaki paketlere uygulanır. LoadMore ve Refresh bunu kullanır.
  String? _categoryId;

  PackagesBloc({required BusinessesRepository repository})
    : _repository = repository,
      super(PackagesInitial()) {
    on<LoadNearbyPackages>(_onLoadNearbyPackages);
    on<LoadPackagesByCategory>(_onLoadPackagesByCategory);
    on<RefreshPackages>(_onRefreshPackages);
    on<LoadMorePackages>(_onLoadMorePackages);
  }

  ({double latitude, double longitude, String? categoryId})? _lastQuery;
  int _loadGeneration = 0;
  bool _catalogLoading = false;
  bool _refreshQueued = false;

  /// Used by visible-tab/resume refresh; preserves the current category and
  /// coalesces timer ticks while a request or pagination is still in flight.
  void refreshCurrent() {
    final query = _lastQuery;
    if (isClosed ||
        query == null ||
        _catalogLoading ||
        _refreshQueued ||
        state is PackagesLoadingMore) {
      return;
    }
    _refreshQueued = true;
    add(
      RefreshPackages(
        latitude: query.latitude,
        longitude: query.longitude,
        categoryId: query.categoryId,
        background: true,
      ),
    );
  }

  Future<void> _onRefreshPackages(
    RefreshPackages event,
    Emitter<PackagesState> emit,
  ) async {
    try {
      await _loadFirstPage(
        latitude: event.latitude,
        longitude: event.longitude,
        categoryId: event.categoryId,
        forceRefresh: true,
        background: event.background,
        emit: emit,
      );
    } finally {
      if (event.onDone != null && !event.onDone!.isCompleted) {
        event.onDone!.complete();
      }
    }
  }

  Future<void> _onLoadNearbyPackages(
    LoadNearbyPackages event,
    Emitter<PackagesState> emit,
  ) => _loadFirstPage(
    latitude: event.latitude,
    longitude: event.longitude,
    emit: emit,
  );

  Future<void> _onLoadPackagesByCategory(
    LoadPackagesByCategory event,
    Emitter<PackagesState> emit,
  ) => _loadFirstPage(
    latitude: event.latitude,
    longitude: event.longitude,
    categoryId: event.categoryId,
    emit: emit,
  );

  Future<void> _loadFirstPage({
    required double latitude,
    required double longitude,
    String? categoryId,
    bool forceRefresh = false,
    bool background = false,
    required Emitter<PackagesState> emit,
  }) async {
    final generation = ++_loadGeneration;
    _catalogLoading = true;
    _refreshQueued = false;
    _categoryId = categoryId;
    _lastQuery = (
      latitude: latitude,
      longitude: longitude,
      categoryId: categoryId,
    );
    final previous = state;
    final hasVisibleList =
        previous is PackagesLoaded && previous.packages.isNotEmpty;
    if (!background && !(forceRefresh && hasVisibleList)) {
      emit(PackagesLoading());
    }
    try {
      final result = await _repository.getNearbyPackages(
        latitude: latitude,
        longitude: longitude,
        radius: 50,
        page: 1,
        limit: 10,
        forceRefresh: forceRefresh,
        categoryId: categoryId,
      );
      if (emit.isDone || generation != _loadGeneration) return;
      if (result.isSuccess) {
        emit(
          PackagesLoaded(
            packages: result.packages!,
            pagination: result.pagination!,
            hasReachedMax:
                result.pagination!.page >= result.pagination!.totalPages,
          ),
        );
      } else if (!background || previous is! PackagesLoaded) {
        emit(PackagesError(message: result.error!));
      }
    } finally {
      if (generation == _loadGeneration) _catalogLoading = false;
    }
  }

  Future<void> _onLoadMorePackages(
    LoadMorePackages event,
    Emitter<PackagesState> emit,
  ) async {
    if (state is! PackagesLoaded || _catalogLoading || _refreshQueued) return;

    final currentState = state as PackagesLoaded;
    final generation = _loadGeneration;

    if (currentState.hasReachedMax) return;

    emit(
      PackagesLoadingMore(
        packages: currentState.packages,
        pagination: currentState.pagination,
      ),
    );

    final result = await _repository.getNearbyPackages(
      latitude: event.latitude,
      longitude: event.longitude,
      radius: 50,
      page: currentState.pagination.page + 1,
      limit: 10,
      categoryId: _categoryId,
    );

    if (emit.isDone || generation != _loadGeneration) return;

    if (result.isSuccess) {
      final allPackages = [...currentState.packages, ...result.packages!];
      emit(
        PackagesLoaded(
          packages: allPackages,
          pagination: result.pagination!,
          hasReachedMax:
              result.pagination!.page >= result.pagination!.totalPages,
        ),
      );
    } else {
      emit(
        PackagesError(message: result.error!, packages: currentState.packages),
      );
    }
  }
}
