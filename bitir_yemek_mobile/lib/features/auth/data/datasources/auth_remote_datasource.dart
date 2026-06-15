import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class AuthRemoteDataSource {
  final DioClient _dioClient;

  AuthRemoteDataSource({required DioClient dioClient}) : _dioClient = dioClient;

  /// Request a one-time login code (OTP) for [email].
  /// Returns `{ message, isNewUser }`.
  Future<Map<String, dynamic>> requestOtp(String email) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/otp/request',
        data: {'email': email},
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Verify the OTP [code] for [email]. For brand-new accounts [name] is
  /// required (and [phone] optional). Returns `{ accessToken, refreshToken, user }`.
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
    String? name,
    String? phone,
  }) async {
    try {
      final data = <String, dynamic>{'email': email, 'code': code};
      if (name != null && name.isNotEmpty) data['name'] = name;
      if (phone != null && phone.isNotEmpty) data['phone'] = phone;

      final response = await _dioClient.dio.post('/auth/otp/verify', data: data);

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> logout() async {
    // Clear auth token from dio client
    _dioClient.clearAuthToken();
  }

  Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    String role = 'customer',
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/google',
        data: {'idToken': idToken, 'role': role},
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> appleLogin({
    required String identityToken,
    required String userIdentifier,
    String? email,
    String? fullName,
    String role = 'customer',
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/apple',
        data: {
          'identityToken': identityToken,
          'userIdentifier': userIdentifier,
          if (email != null) 'email': email,
          if (fullName != null) 'fullName': fullName,
          'role': role,
        },
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return AuthException(
        message: 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    } else if (e.type == DioExceptionType.connectionError) {
      return AuthException(
        message:
            'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edin.',
      );
    } else if (e.response != null) {
      final data = e.response?.data as Map<String, dynamic>?;
      final message = data?['message'] as String? ?? 'Bir hata oluştu';
      final errors = data?['errors'] as List<dynamic>?;

      return AuthException(
        message: message,
        errors: errors?.cast<String>(),
        statusCode: e.response?.statusCode,
      );
    }

    return AuthException(
      message: 'Bağlantı hatası. Lütfen internet bağlantınızı kontrol edin.',
    );
  }
}

class AuthException implements Exception {
  final String message;
  final List<String>? errors;
  final int? statusCode;

  AuthException({required this.message, this.errors, this.statusCode});

  @override
  String toString() => message;
}
