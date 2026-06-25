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

  Future<void> _onRefreshPackages(
    RefreshPackages event,
    Emitter<PackagesState> emit,
  ) async {
    _categoryId = event.categoryId;
    // Görünür (dolu) bir liste varsa onu koru (pull-to-refresh akıcı kalsın);
    // boş/hata durumundan yenilenirken shimmer göster ki "Yenile" butonu geri
    // bildirim versin. Her iki durumda da cache bypass ile taze veri çekilir;
    // kategori filtresi yakındaki paketlere uygulanır (Hepsi ile aynı bağlam).
    final current = state;
    final hasVisibleList =
        current is PackagesLoaded && current.packages.isNotEmpty;
    if (!hasVisibleList) {
      emit(PackagesLoading());
    }
    try {
      final result = await _repository.getNearbyPackages(
        latitude: event.latitude,
        longitude: event.longitude,
        radius: 50,
        page: 1,
        limit: 10,
        forceRefresh: true,
        categoryId: event.categoryId,
      );

      if (result.isSuccess) {
        emit(
          PackagesLoaded(
            packages: result.packages!,
            pagination: result.pagination!,
            hasReachedMax:
                result.pagination!.page >= result.pagination!.totalPages,
          ),
        );
      } else {
        emit(PackagesError(message: result.error!));
      }
    } finally {
      // Veri öncekiyle aynı olsa (state bastırılsa) bile spinner takılmasın.
      if (event.onDone != null && !event.onDone!.isCompleted) {
        event.onDone!.complete();
      }
    }
  }

  Future<void> _onLoadNearbyPackages(
    LoadNearbyPackages event,
    Emitter<PackagesState> emit,
  ) async {
    _categoryId = null;
    emit(PackagesLoading());

    final result = await _repository.getNearbyPackages(
      latitude: event.latitude,
      longitude: event.longitude,
      radius: 50,
      page: 1,
      limit: 10,
    );

    if (result.isSuccess) {
      emit(
        PackagesLoaded(
          packages: result.packages!,
          pagination: result.pagination!,
          hasReachedMax:
              result.pagination!.page >= result.pagination!.totalPages,
        ),
      );
    } else {
      emit(PackagesError(message: result.error!));
    }
  }

  Future<void> _onLoadPackagesByCategory(
    LoadPackagesByCategory event,
    Emitter<PackagesState> emit,
  ) async {
    _categoryId = event.categoryId;
    emit(PackagesLoading());

    // Kategori filtresini konuma duyarlı uygula (Hepsi ile tutarlı, yakındaki).
    final result = await _repository.getNearbyPackages(
      latitude: event.latitude,
      longitude: event.longitude,
      radius: 50,
      page: 1,
      limit: 10,
      categoryId: event.categoryId,
    );

    if (result.isSuccess) {
      emit(
        PackagesLoaded(
          packages: result.packages!,
          pagination: result.pagination!,
          hasReachedMax:
              result.pagination!.page >= result.pagination!.totalPages,
        ),
      );
    } else {
      emit(PackagesError(message: result.error!));
    }
  }

  Future<void> _onLoadMorePackages(
    LoadMorePackages event,
    Emitter<PackagesState> emit,
  ) async {
    if (state is! PackagesLoaded) return;

    final currentState = state as PackagesLoaded;

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
