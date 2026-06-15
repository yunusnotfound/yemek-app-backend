import 'package:flutter_bloc/flutter_bloc.dart';
import 'map_event.dart';
import 'map_state.dart';
import '../../domain/repositories/map_repository.dart';

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
        emit(MapLoaded(businesses: result.businesses!));
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
    if (currentState is MapLoaded) {
      emit(currentState.copyWith(selectedBusiness: event.business));
    }
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
