import '../datasources/map_remote_datasource.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/package_model.dart';
import '../../domain/repositories/map_repository.dart';

class MapRepositoryImpl implements MapRepository {
  final MapRemoteDataSource _remoteDataSource;

  MapRepositoryImpl({required MapRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<MapBusinessesResult> getBusinessesForMap({
    required double lat,
    required double lng,
    double radius = 10.0,
  }) async {
    try {
      final businesses = await _remoteDataSource.getBusinessesForMap(
        latitude: lat,
        longitude: lng,
        radius: radius,
      );

      return MapBusinessesResult.success(businesses: businesses);
    } on MapException catch (e) {
      return MapBusinessesResult.failure(e.message);
    } catch (e) {
      return MapBusinessesResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<DirectionsResult> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final directions = await _remoteDataSource.getDirections(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );

      return DirectionsResult.success(directions: directions);
    } on MapException catch (e) {
      return DirectionsResult.failure(e.message);
    } catch (e) {
      return DirectionsResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<BusinessPackagesResult> getBusinessPackages(String businessId) async {
    try {
      final packages = await _remoteDataSource.getBusinessPackages(businessId);
      return BusinessPackagesResult.success(packages: packages);
    } on MapException catch (e) {
      return BusinessPackagesResult.failure(e.message);
    } catch (e) {
      return BusinessPackagesResult.failure('Bir hata oluştu: $e');
    }
  }
}

class MapBusinessesResult {
  final bool isSuccess;
  final List<BusinessModel>? businesses;
  final String? error;

  MapBusinessesResult._({required this.isSuccess, this.businesses, this.error});

  factory MapBusinessesResult.success({
    required List<BusinessModel> businesses,
  }) {
    return MapBusinessesResult._(isSuccess: true, businesses: businesses);
  }

  factory MapBusinessesResult.failure(String error) {
    return MapBusinessesResult._(isSuccess: false, error: error);
  }
}

class BusinessPackagesResult {
  final bool isSuccess;
  final List<PackageModel>? packages;
  final String? error;

  BusinessPackagesResult._({
    required this.isSuccess,
    this.packages,
    this.error,
  });

  factory BusinessPackagesResult.success({
    required List<PackageModel> packages,
  }) {
    return BusinessPackagesResult._(isSuccess: true, packages: packages);
  }

  factory BusinessPackagesResult.failure(String error) {
    return BusinessPackagesResult._(isSuccess: false, error: error);
  }
}

class DirectionsResult {
  final bool isSuccess;
  final Map<String, dynamic>? directions;
  final String? error;

  DirectionsResult._({required this.isSuccess, this.directions, this.error});

  factory DirectionsResult.success({required Map<String, dynamic> directions}) {
    return DirectionsResult._(isSuccess: true, directions: directions);
  }

  factory DirectionsResult.failure(String error) {
    return DirectionsResult._(isSuccess: false, error: error);
  }
}
