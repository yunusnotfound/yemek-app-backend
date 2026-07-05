import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class CardsRemoteDataSource {
  final DioClient _dioClient;

  CardsRemoteDataSource({required DioClient dioClient})
    : _dioClient = dioClient;

  Future<List<Map<String, dynamic>>> getCards() async {
    try {
      final response = await _dioClient.dio.get('/cards');
      final data = response.data as Map<String, dynamic>;
      final cards = data['cards'] as List<dynamic>? ?? [];
      return cards.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> addCard({
    required String cardHolderName,
    required String cardNumber,
    required String expireMonth,
    required String expireYear,
    String? cardAlias,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/cards',
        data: {
          'cardHolderName': cardHolderName,
          'cardNumber': cardNumber,
          'expireMonth': expireMonth,
          'expireYear': expireYear,
          if (cardAlias != null && cardAlias.isNotEmpty) 'cardAlias': cardAlias,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> deleteCard(String cardToken) async {
    try {
      await _dioClient.dio.delete('/cards/$cardToken');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data as Map<String, dynamic>?;
      final message = data?['message'] as String? ?? 'Bir hata olustu';
      return CardsException(message: message, statusCode: e.response?.statusCode);
    }
    return CardsException(
      message: 'Baglanti hatasi. Lutfen internet baglantinizi kontrol edin.',
    );
  }
}

class CardsException implements Exception {
  final String message;
  final int? statusCode;

  CardsException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
