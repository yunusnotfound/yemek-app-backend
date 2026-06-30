import 'package:flutter_bloc/flutter_bloc.dart';
import 'map_event.dart';
import 'map_state.dart';
import '../../domain/repositories/map_repository.dart';
import '../../../home/data/models/package_model.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final MapRepository _repository;

  MapBloc({required MapRepository repository})
    : _repository = repository,
      super(const MapInitial()) {
    on<LoadBusinessesForMap>(_onLoadBusinessesForMap);
    on<SelectBusiness>(_onSelectBusiness);
    on<ClearSelection>(_onClearSelection);
    on<RequestDirections>(_onRequestDirections);
    on<ClearDirections>(_onClearDirections);
  }

  Future<void> _onLoadBusinessesForMap(
    LoadBusinessesForMap event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapLoading());

    try {
      final result = await _repository.getBusinessesForMap(
        lat: event.latitude,
        lng: event.longitude,
        radius: event.radius,
      );

      if (result.isSuccess && result.businesses != null) {
        // Markerlar hemen görünsün diye işletmeleri önce emit et.
        emit(MapLoaded(businesses: result.businesses!));

        // Alt liste paneli için yakındaki paketleri ayrıca yükle.
        final pkgResult = await _repository.getNearbyPackages(
          lat: event.latitude,
          lng: event.longitude,
          radius: event.radius,
        );
        final latest = state;
        if (latest is MapLoaded &&
            pkgResult.isSuccess &&
            pkgResult.packages != null) {
          emit(latest.copyWith(packages: pkgResult.packages));
        }
      } else {
        emit(MapError(message: result.error ?? 'Bilinmeyen hata'));
      }
    } catch (e) {
      emit(MapError(message: e.toString()));
    }
  }

  Future<void> _onSelectBusiness(
    SelectBusiness event,
    Emitter<MapState> emit,
  ) async {
    final currentState = state;
    if (currentState is! MapLoaded) return;

    // Kartı hemen aç; paket yüklenirken iskelet göster.
    emit(
      currentState.copyWith(
        selectedBusiness: event.business,
        clearPackage: true,
        packageLoading: true,
      ),
    );

    final result = await _repository.getBusinessPackages(event.business.id);

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

    try {
      final result = await _repository.getDirections(
        originLat: event.originLat,
        originLng: event.originLng,
        destLat: event.destLat,
        destLng: event.destLng,
      );

      if (result.isSuccess && result.directions != null) {
        emit(currentState.copyWith(directions: result.directions));
      } else {
        // Surface the failure so the UI can show feedback, then restore the
        // loaded map (with directions cleared) so markers stay visible.
        emit(
          MapError(
            message: result.error ?? 'Yol tarifi alınamadı',
            businesses: currentState.businesses,
          ),
        );
        emit(currentState.copyWith(clearDirections: true));
      }
    } catch (e) {
      emit(
        MapError(
          message: 'Yol tarifi alınırken bir hata oluştu',
          businesses: currentState.businesses,
        ),
      );
      emit(currentState.copyWith(clearDirections: true));
    }
  }

  Future<void> _onClearDirections(
    ClearDirections event,
    Emitter<MapState> emit,
  ) async {
    final currentState = state;
    if (currentState is MapLoaded) {
      emit(currentState.copyWith(clearDirections: true));
    }
  }
}
