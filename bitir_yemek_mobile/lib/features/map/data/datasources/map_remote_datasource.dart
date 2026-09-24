import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/package_availability.dart';
import '../../../../config/constants.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/package_model.dart';

class MapRemoteDataSource {
  final DioClient _dioClient;

  MapRemoteDataSource({required DioClient dioClient}) : _dioClient = dioClient;

  Future<List<BusinessModel>> getBusinessesForMap({
    required double latitude,
    required double longitude,
    double radius = 10.0,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/maps/nearby',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius': radius,
          'limit': 100,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final businessesData = data['businesses'] as List<dynamic>?;

      if (businessesData == null) {
        return [];
      }

      final businesses = businessesData.cast<Map<String, dynamic>>();
      final visible = List<BusinessModel?>.filled(businesses.length, null);
      var nextIndex = 0;
      // Older servers do not include package metadata in /maps/nearby. Resolve
      // those businesses with bounded concurrency rather than treating the
      // first, paginated /packages response as the entire nearby catalog.
      Future<void> resolveBusinesses() async {
        while (nextIndex < businesses.length) {
          final index = nextIndex++;
          final business = businesses[index];
          List<dynamic>? packageData = business['packages'] as List<dynamic>?;
          if (packageData == null) {
            try {
              final detail = await _dioClient.dio.get(
                '/businesses/${business['id']}',
              );
              final detailData = detail.data as Map<String, dynamic>;
              final detailBusiness =
                  detailData['business'] as Map<String, dynamic>?;
              packageData = detailBusiness?['packages'] as List<dynamic>? ?? [];
            } on DioException catch (error) {
              if (error.response?.statusCode == 404) continue;
              rethrow;
            }
          }
          final now = DateTime.now();
          final available = packageData
              .cast<Map<String, dynamic>>()
              .where((package) => isPackageAvailable(package, now: now))
              .toList();
          if (available.isEmpty) continue;
          visible[index] = BusinessModel.fromJson({
            ...business,
            'packageCount': available.length,
            'availableUntil': available
                .map((package) => packagePickupEnd(package)!)
                .reduce((a, b) => a.isAfter(b) ? a : b)
                .toIso8601String(),
            'availableNow': available.any((package) {
              final day = package['pickupDate'].toString().substring(0, 10);
              final start = DateTime.tryParse(
                '${day}T${package['pickupStart']}+03:00',
              );
              return start != null && !start.isAfter(now);
            }),
          });
        }
      }

      await Future.wait(
        List.generate(
          businesses.length < 4 ? businesses.length : 4,
          (_) => resolveBusinesses(),
        ),
      );
      return visible.whereType<BusinessModel>().toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// İşletme detayını çekip aktif paketlerini döndürür (GET /businesses/:id).
  /// PackageModel.fromJson iç içe `business` beklediğinden, her pakete parent
  /// işletmeyi (packages alanı çıkarılmış) enjekte ederiz.
  Future<List<PackageModel>> getBusinessPackages(String businessId) async {
    try {
      final response = await _dioClient.dio.get('/businesses/$businessId');

      final data = response.data as Map<String, dynamic>;
      final businessJson = data['business'] as Map<String, dynamic>?;
      if (businessJson == null) return [];

      final pkgs = (businessJson['packages'] as List<dynamic>?) ?? const [];
      final businessForPkg = Map<String, dynamic>.of(businessJson)
        ..remove('packages');

      return pkgs
          .cast<Map<String, dynamic>>()
          .where(isPackageAvailable)
          .map((p) => PackageModel.fromJson({...p, 'business': businessForPkg}))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Konuma yakın aktif paketleri döndürür (GET /packages?lat&lng&radius).
  /// Keşfet ekranıyla aynı uç; her paket iç içe `business` taşır.
  Future<List<PackageModel>> getNearbyPackages({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int limit = 100,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/packages',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius': radius,
          'limit': limit,
          'excludeExpired': 'true',
        },
      );

      final data = response.data as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where(isPackageAvailable)
          .map(PackageModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      // Use a separate plain Dio instance for external API
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final url =
          'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '$originLng,$originLat;$destLng,$destLat'
          '?geometries=geojson&overview=full&access_token=${AppConstants.mapboxAccessToken}';

      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;

        if (routes == null || routes.isEmpty) {
          throw MapException(message: 'Rota bulunamadı');
        }

        final route = routes.first as Map<String, dynamic>;
        final geometry = route['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List<dynamic>?;

        return {
          'distance': route['distance'] as num? ?? 0, // meters
          'duration': route['duration'] as num? ?? 0, // seconds
          'geometry': coordinates ?? [],
        };
      } else {
        throw MapException(message: 'Rota alınamadı');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data as Map<String, dynamic>?;
      final message = data?['message'] as String? ?? 'Bir hata oluştu';
      return MapException(message: message);
    }

    return MapException(
      message: 'Bağlantı hatası. Lütfen internet bağlantınızı kontrol edin.',
    );
  }
}

class MapException implements Exception {
  final String message;

  MapException({required this.message});

  @override
  String toString() => message;
}
