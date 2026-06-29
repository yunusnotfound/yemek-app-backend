import '../../data/repositories/map_repository_impl.dart';

abstract class MapRepository {
  Future<MapBusinessesResult> getBusinessesForMap({
    required double lat,
    required double lng,
    double radius = 10.0,
  });

  Future<DirectionsResult> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  });

  Future<BusinessPackagesResult> getBusinessPackages(String businessId);
}
