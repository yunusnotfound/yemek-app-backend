import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/owner_package_model.dart';
import '../../domain/repositories/business_owner_repository.dart';

part 'owner_packages_event.dart';
part 'owner_packages_state.dart';

class OwnerPackagesBloc extends Bloc<OwnerPackagesEvent, OwnerPackagesState> {
  final BusinessOwnerRepository _repository;
  String? _currentBusinessId;
  int _generation = 0;

  OwnerPackagesBloc({required BusinessOwnerRepository repository})
    : _repository = repository,
      super(OwnerPackagesInitial()) {
    on<LoadBusinessPackages>(_onLoadBusinessPackages);
    on<DeletePackage>(_onDeletePackage);
    on<RefreshPackages>(_onRefreshPackages);
  }

  Future<void> _onLoadBusinessPackages(
    LoadBusinessPackages event,
    Emitter<OwnerPackagesState> emit,
  ) async {
    final generation = ++_generation;
    _currentBusinessId = event.businessId;
    emit(OwnerPackagesLoading());
    try {
      final packages = await _repository.getBusinessPackages(event.businessId);
      if (emit.isDone || generation != _generation) return;
      emit(OwnerPackagesLoaded(packages: packages));
    } catch (e) {
      if (emit.isDone || generation != _generation) return;
      emit(OwnerPackagesError(message: e.toString()));
    }
  }

  Future<void> _onDeletePackage(
    DeletePackage event,
    Emitter<OwnerPackagesState> emit,
  ) async {
    final generation = ++_generation;
    try {
      await _repository.deletePackage(event.packageId);
      if (emit.isDone || generation != _generation) return;
      emit(PackageDeleted());
      // Reload packages after deletion
      if (_currentBusinessId != null) {
        final packages = await _repository.getBusinessPackages(
          _currentBusinessId!,
        );
        if (emit.isDone || generation != _generation) return;
        emit(OwnerPackagesLoaded(packages: packages));
      }
    } catch (e) {
      if (emit.isDone || generation != _generation) return;
      emit(PackageDeleteError(message: e.toString()));
      // Restore loaded state if we had one
      if (_currentBusinessId != null) {
        try {
          final packages = await _repository.getBusinessPackages(
            _currentBusinessId!,
          );
          if (emit.isDone || generation != _generation) return;
          emit(OwnerPackagesLoaded(packages: packages));
        } catch (_) {}
      }
    }
  }

  Future<void> _onRefreshPackages(
    RefreshPackages event,
    Emitter<OwnerPackagesState> emit,
  ) async {
    if (_currentBusinessId == null) return;
    final generation = ++_generation;
    emit(OwnerPackagesLoading());
    try {
      final packages = await _repository.getBusinessPackages(
        _currentBusinessId!,
      );
      if (emit.isDone || generation != _generation) return;
      emit(OwnerPackagesLoaded(packages: packages));
    } catch (e) {
      if (emit.isDone || generation != _generation) return;
      emit(OwnerPackagesError(message: e.toString()));
    }
  }
}
