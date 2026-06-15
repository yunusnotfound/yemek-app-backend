import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../config/constants.dart';
import '../../core/storage/token_storage.dart';

class DioClient {
  late final Dio _dio;

  DioClient({TokenStorage? tokenStorage}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeout,
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (tokenStorage != null) {
      _dio.interceptors.add(
        AuthInterceptor(tokenStorage: tokenStorage, dio: _dio),
      );
    }

    // Only add verbose logging in debug mode
    if (!kReleaseMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, error: true),
      );
    }
  }

  Dio get dio => _dio;

  // Kept for manual override (e.g. right after login before interceptor loads)
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

/// Automatically injects Bearer token on every request.
/// On 401, attempts a silent token refresh and retries the original request.
/// On refresh failure, clears tokens (forces re-login).
class AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  final Dio dio;
  bool _isRefreshing = false;
  int _refreshAttempts = 0;
  static const int _maxRefreshAttempts = 2;

  // Queue for pending requests while token is being refreshed
  final List<({ErrorInterceptorHandler handler, RequestOptions options})>
  _pendingRequests = [];

  AuthInterceptor({required this.tokenStorage, required this.dio});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Check if we've exceeded max refresh attempts
      if (_refreshAttempts >= _maxRefreshAttempts) {
        await tokenStorage.clearTokens();
        _refreshAttempts = 0;
        handler.next(err);
        return;
      }

      // If already refreshing, queue this request and return
      if (_isRefreshing) {
        _pendingRequests.add((handler: handler, options: err.requestOptions));
        return;
      }

      _isRefreshing = true;
      _refreshAttempts++;

      try {
        final refreshToken = await tokenStorage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          await tokenStorage.clearTokens();
          _refreshAttempts = 0;
          _rejectAllPending(err);
          handler.next(err);
          return;
        }

        // Use a separate Dio instance to avoid interceptor loop
        final refreshDio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            headers: {'Content-Type': 'application/json'},
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        final response = await refreshDio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );

        // Parse defensively — a malformed/unexpected refresh response must not
        // throw a TypeError. Treat missing/non-string tokens as a refresh
        // failure (forces re-login) instead of crashing the interceptor.
        final data = response.data;
        final newAccessToken = (data is Map ? data['accessToken'] : null);
        final newRefreshToken = (data is Map ? data['refreshToken'] : null);

        if (newAccessToken is! String ||
            newAccessToken.isEmpty ||
            newRefreshToken is! String ||
            newRefreshToken.isEmpty) {
          await tokenStorage.clearTokens();
          _refreshAttempts = 0;
          _rejectAllPending(err);
          handler.next(err);
          return;
        }

        await tokenStorage.saveAccessToken(newAccessToken);
        await tokenStorage.saveRefreshToken(newRefreshToken);

        // Reset refresh attempts on success
        _refreshAttempts = 0;

        // Retry original request with the new token
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await dio.fetch(err.requestOptions);

        // Retry all pending requests with the new token
        await _retryAllPending(newAccessToken);

        handler.resolve(retryResponse);
      } catch (e) {
        await tokenStorage.clearTokens();
        _refreshAttempts = 0;
        _rejectAllPending(err);
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }

  /// Retry all pending requests with the new token
  Future<void> _retryAllPending(String newToken) async {
    final pendingRequests = List.of(_pendingRequests);
    _pendingRequests.clear();

    for (final pending in pendingRequests) {
      try {
        pending.options.headers['Authorization'] = 'Bearer $newToken';
        final response = await dio.fetch(pending.options);
        pending.handler.resolve(response);
      } catch (e) {
        pending.handler.next(
          DioException(requestOptions: pending.options, error: e),
        );
      }
    }
  }

  /// Reject all pending requests with an error
  void _rejectAllPending(DioException error) {
    final pendingRequests = List.of(_pendingRequests);
    _pendingRequests.clear();

    for (final pending in pendingRequests) {
      pending.handler.next(error);
    }
  }
}
