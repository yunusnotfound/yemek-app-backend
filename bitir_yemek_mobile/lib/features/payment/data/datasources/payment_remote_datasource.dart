import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class PaymentRemoteDataSource {
  final DioClient _dioClient;

  PaymentRemoteDataSource({required DioClient dioClient}) : _dioClient = dioClient;

  /// Ödeme durumunu sorgula. [sync] true ise backend tek seferlik iyzico retrieve tetikler.
  Future<Map<String, dynamic>> getStatus(String conversationId, {bool sync = false}) async {
    try {
      final response = await _dioClient.dio.get(
        '/payments/$conversationId/status',
        queryParameters: sync ? {'sync': '1'} : null,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data as Map<String, dynamic>?;
      final message = data?['message'] as String? ?? 'Bir hata oluştu';
      return PaymentException(message: message);
    }
    return PaymentException(message: 'Bağlantı hatası. Lütfen tekrar deneyin.');
  }
}

class PaymentException implements Exception {
  final String message;
  PaymentException({required this.message});

  @override
  String toString() => message;
}
