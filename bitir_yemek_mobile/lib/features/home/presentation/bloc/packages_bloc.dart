import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/business_model.dart';
import '../../data/models/package_model.dart';
import '../../domain/repositories/businesses_repository.dart';

part 'packages_event.dart';
part 'packages_state.dart';

class PackagesBloc extends Bloc<PackagesEvent, PackagesState> {
  final BusinessesRepository _repository;

  PackagesBloc({required BusinessesRepository repository})
    : _repository = repository,
      super(PackagesInitial()) {
    on<LoadNearbyPackages>(_onLoadNearbyPackages);
    on<LoadPackagesByCategory>(_onLoadPackagesByCategory);
    on<LoadMorePackages>(_onLoadMorePackages);
  }

  Future<void> _onLoadNearbyPackages(
    LoadNearbyPackages event,
    Emitter<PackagesState> emit,
  ) async {
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
    emit(PackagesLoading());

    final result = await _repository.getPackages(
      categoryId: event.categoryId,
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
