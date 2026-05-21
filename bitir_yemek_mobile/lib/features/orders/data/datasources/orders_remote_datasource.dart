import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class OrdersRemoteDataSource {
  final DioClient _dioClient;

  OrdersRemoteDataSource({required DioClient dioClient}) : _dioClient = dioClient;

  Future<Map<String, dynamic>> getMyOrders({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/orders',
        queryParameters: {'page': page, 'limit': limit},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      final response = await _dioClient.dio.patch('/orders/$orderId/cancel');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data as Map<String, dynamic>?;
      final message = data?['message'] as String? ?? 'Bir hata olustu';
      return OrdersException(
        message: message,
        statusCode: e.response?.statusCode,
      );
    }
    return OrdersException(
      message: 'Baglanti hatasi. Lutfen internet baglantinizi kontrol edin.',
    );
  }
}

class OrdersException implements Exception {
  final String message;
  final int? statusCode;

  OrdersException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
