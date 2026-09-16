import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'map_event.dart';
import 'map_state.dart';
import '../../domain/repositories/map_repository.dart';
import '../../../home/data/models/package_model.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final MapRepository _repository;
  int _directionGeneration = 0;
  int _loadGeneration = 0;
  bool _catalogLoading = false;
  bool _refreshQueued = false;
  LoadBusinessesForMap? _lastQuery;

  /// Reuses the chosen map area, without moving the camera or clearing filters.
  void refreshCurrent() {
    final query = _lastQuery;
    if (isClosed || query == null || _catalogLoading || _refreshQueued) return;
    _refreshQueued = true;
    add(
      LoadBusinessesForMap(
        latitude: query.latitude,
        longitude: query.longitude,
        radius: query.radius,
        background: true,
      ),
    );
  }

  MapBloc({required MapRepository repository})
    : _repository = repository,
      super(const MapInitial()) {
    on<LoadBusinessesForMap>(
      _onLoadBusinessesForMap,
      transformer: restartable(),
    );
    on<SelectBusiness>(_onSelectBusiness, transformer: restartable());
    on<ClearSelection>(_onClearSelection);
    on<RequestDirections>(_onRequestDirections, transformer: restartable());
    on<ClearDirections>(_onClearDirections);
  }

  Future<void> _onLoadBusinessesForMap(
    LoadBusinessesForMap event,
    Emitter<MapState> emit,
  ) async {
    final generation = ++_loadGeneration;
    _catalogLoading = true;
    _refreshQueued = false;
    _lastQuery = event;
    final keepVisible = event.background && state is MapLoaded;
    if (!keepVisible) {
      _directionGeneration++;
      emit(const MapLoading());
    }

    try {
      final result = await _repository.getBusinessesForMap(
        lat: event.latitude,
        lng: event.longitude,
        radius: event.radius,
      );
      if (emit.isDone) return;

      if (result.isSuccess && result.businesses != null) {
        final current = state;
        if (keepVisible && current is MapLoaded) {
          final selectedId = current.selectedBusiness?.id;
          final selected = result.businesses!
              .where((business) => business.id == selectedId)
              .firstOrNull;
          if (selectedId != null && selected == null) _directionGeneration++;
          emit(
            current.copyWith(
              businesses: result.businesses!,
              selectedBusiness: selected,
              clearSelection: selected == null,
              clearDirections: selected == null,
            ),
          );
        } else {
          emit(MapLoaded(businesses: result.businesses!));
        }

        final pkgResult = await _repository.getNearbyPackages(
          lat: event.latitude,
          lng: event.longitude,
          radius: event.radius,
        );
        if (emit.isDone) return;
        final latest = state;
        if (latest is MapLoaded &&
            pkgResult.isSuccess &&
            pkgResult.packages != null) {
          emit(latest.copyWith(packages: pkgResult.packages));
        }

        // A selected card also needs current stock after an owner edits it.
        final selectedState = state;
        if (keepVisible &&
            selectedState is MapLoaded &&
            selectedState.selectedBusiness != null) {
          final selectedId = selectedState.selectedBusiness!.id;
          final selectedResult = await _repository.getBusinessPackages(
            selectedId,
          );
          if (emit.isDone) return;
          final current = state;
          if (current is MapLoaded &&
              current.selectedBusiness?.id == selectedId &&
              selectedResult.isSuccess) {
            final package = _pickRepresentativePackage(
              selectedResult.packages!,
            );
            emit(
              current.copyWith(
                selectedPackage: package,
                clearPackage: package == null,
                packageLoading: false,
              ),
            );
          }
        }
      } else if (!keepVisible) {
        emit(MapError(message: result.error ?? 'Bilinmeyen hata'));
      }
    } catch (e) {
      if (emit.isDone || keepVisible) return;
      emit(MapError(message: e.toString()));
    } finally {
      if (generation == _loadGeneration) _catalogLoading = false;
    }
  }

  Future<void> _onSelectBusiness(
    SelectBusiness event,
    Emitter<MapState> emit,
  ) async {
    final currentState = state;
    if (currentState is! MapLoaded) return;
    _directionGeneration++;

    // Kartı hemen aç; paket yüklenirken iskelet göster.
    emit(
      currentState.copyWith(
        selectedBusiness: event.business,
        clearPackage: true,
        clearDirections: true,
        packageLoading: true,
      ),
    );

    final result = await _repository.getBusinessPackages(event.business.id);
    if (emit.isDone) return;

    // Kullanıcı bu sırada başka işletme seçtiyse eski sonucu yazma.
    final latest = state;
    if (latest is! MapLoaded ||
        latest.selectedBusiness?.id != event.business.id) {
      return;
    }

    if (result.isSuccess && result.packages != null) {
      emit(
        latest.copyWith(
          selectedPackage: _pickRepresentativePackage(result.packages!),
          packageLoading: false,
        ),
      );
    } else {
      emit(latest.copyWith(packageLoading: false));
    }
  }

  /// pickupDate >= bugün olan paketlerden (pickupDate, pickupStart)'a göre
  /// en yakın olanı seçer; yoksa null.
  PackageModel? _pickRepresentativePackage(List<PackageModel> packages) {
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final upcoming =
        packages.where((p) => p.pickupDate.compareTo(todayStr) >= 0).toList()
          ..sort((a, b) {
            final dateCmp = a.pickupDate.compareTo(b.pickupDate);
            if (dateCmp != 0) return dateCmp;
            return a.pickupStart.compareTo(b.pickupStart);
          });

    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Future<void> _onClearSelection(
    ClearSelection event,
    Emitter<MapState> emit,
  ) async {
    _directionGeneration++;
    final currentState = state;
    if (currentState is MapLoaded) {
      emit(currentState.copyWith(clearSelection: true, clearDirections: true));
    }
  }

  Future<void> _onRequestDirections(
    RequestDirections event,
    Emitter<MapState> emit,
  ) async {
    final currentState = state;
    if (currentState is! MapLoaded) return;
    final generation = ++_directionGeneration;

    try {
      final result = await _repository.getDirections(
        originLat: event.originLat,
        originLng: event.originLng,
        destLat: event.destLat,
        destLng: event.destLng,
      );
      if (emit.isDone || generation != _directionGeneration) return;
      final latest = state;
      if (latest is! MapLoaded) return;

      if (result.isSuccess && result.directions != null) {
        emit(latest.copyWith(directions: result.directions));
      } else {
        // Surface the failure so the UI can show feedback, then restore the
        // loaded map (with directions cleared) so markers stay visible.
        emit(
          MapError(
            message: result.error ?? 'Yol tarifi alınamadı',
            businesses: latest.businesses,
          ),
        );
        emit(latest.copyWith(clearDirections: true));
      }
    } catch (e) {
      if (emit.isDone || generation != _directionGeneration) return;
      final latest = state;
      if (latest is! MapLoaded) return;
      emit(
        MapError(
          message: 'Yol tarifi alınırken bir hata oluştu',
          businesses: latest.businesses,
        ),
      );
      emit(latest.copyWith(clearDirections: true));
    }
  }

  Future<void> _onClearDirections(
    ClearDirections event,
    Emitter<MapState> emit,
  ) async {
    _directionGeneration++;
    final currentState = state;
    if (currentState is MapLoaded) {
      emit(currentState.copyWith(clearDirections: true));
    }
  }
}
