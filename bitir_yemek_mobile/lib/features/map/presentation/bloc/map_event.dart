import 'package:equatable/equatable.dart';
import '../../../home/data/models/business_model.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

class LoadBusinessesForMap extends MapEvent {
  final double latitude;
  final double longitude;
  final double radius;
  final bool background;

  const LoadBusinessesForMap({
    required this.latitude,
    required this.longitude,
    this.radius = 10.0,
    this.background = false,
  });

  @override
  List<Object?> get props => [latitude, longitude, radius, background];
}

class SelectBusiness extends MapEvent {
  final BusinessModel business;

  const SelectBusiness({required this.business});

  @override
  List<Object?> get props => [business];
}

class ClearSelection extends MapEvent {
  const ClearSelection();
}

class RequestDirections extends MapEvent {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;

  const RequestDirections({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
  });

  @override
  List<Object?> get props => [originLat, originLng, destLat, destLng];
}

class ClearDirections extends MapEvent {
  const ClearDirections();
}
