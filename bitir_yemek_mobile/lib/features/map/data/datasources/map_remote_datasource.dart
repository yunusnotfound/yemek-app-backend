import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
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

      return businessesData
          .map((e) => BusinessModel.fromJson(e as Map<String, dynamic>))
          .toList();
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
          .map(
            (p) => PackageModel.fromJson({
              ...p as Map<String, dynamic>,
              'business': businessForPkg,
            }),
          )
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
