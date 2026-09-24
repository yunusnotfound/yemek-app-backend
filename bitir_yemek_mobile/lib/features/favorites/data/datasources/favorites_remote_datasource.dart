import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class FavoritesRemoteDataSource {
  final DioClient _dioClient;

  FavoritesRemoteDataSource({required DioClient dioClient})
    : _dioClient = dioClient;

  Future<Map<String, dynamic>> getFavorites({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/favorites',
        queryParameters: {'page': page, 'limit': limit},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> addFavorite(String businessId) async {
    try {
      final response = await _dioClient.dio.post(
        '/favorites',
        data: {'businessId': businessId},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Compatibility with servers that do not yet include package availability
  /// in the favorites response. New responses require no detail requests.
  Future<List<dynamic>> getBusinessPackages(String businessId) async {
    try {
      final response = await _dioClient.dio.get('/businesses/$businessId');
      final data = response.data as Map<String, dynamic>;
      final business = data['business'] as Map<String, dynamic>?;
      return business?['packages'] as List<dynamic>? ?? [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw _handleDioError(e);
    }
  }

  Future<void> removeFavorite(String businessId) async {
    try {
      await _dioClient.dio.delete('/favorites/$businessId');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> checkFavorite(String businessId) async {
    try {
      final response = await _dioClient.dio.get('/favorites/check/$businessId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data as Map<String, dynamic>?;
      final message = data?['message'] as String? ?? 'Bir hata olustu';
      return FavoritesException(
        message: message,
        statusCode: e.response?.statusCode,
      );
    }
    return FavoritesException(
      message: 'Baglanti hatasi. Lutfen internet baglantinizi kontrol edin.',
    );
  }
}

class FavoritesException implements Exception {
  final String message;
  final int? statusCode;

  FavoritesException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
