import 'package:dio/dio.dart';
import '../../config/constants.dart';
import '../../core/storage/token_storage.dart';

class DioClient {
  late final Dio _dio;
  final TokenStorage? _tokenStorage;
  AuthInterceptor? _authInterceptor;

  DioClient({TokenStorage? tokenStorage}) : _tokenStorage = tokenStorage {
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
      _authInterceptor = AuthInterceptor(tokenStorage: tokenStorage, dio: _dio);
      _dio.interceptors.add(_authInterceptor!);
    }
    // Request/response logging can expose PAN, CVV, OTPs and session tokens,
    // including profile builds connected to the production API.
  }

  Future<void> logout() async {
    try {
      await _authInterceptor?.finishRefresh();
      final refreshToken = await _tokenStorage?.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } finally {
      clearAuthToken();
      await _tokenStorage?.clearTokens();
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
  Future<String?>? _refreshFuture;

  AuthInterceptor({required this.tokenStorage, required this.dio});

  Future<void> finishRefresh() async {
    await _refreshFuture;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        options.headers.remove('Authorization');
      }
      handler.next(options);
    } catch (e) {
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  Future<String?> _refresh() async {
    final previous = await tokenStorage.getRefreshToken();
    if (previous == null || previous.isEmpty) return null;
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: dio.options.baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    try {
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': previous},
      );
      final data = response.data;
      final access = data is Map ? data['accessToken'] : null;
      final refresh = data is Map ? data['refreshToken'] : null;
      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty) {
        return null;
      }
      // A completed sign-out/new login must not be overwritten by an old request.
      if (await tokenStorage.getRefreshToken() != previous) return null;
      await tokenStorage.saveAccessToken(access);
      await tokenStorage.saveRefreshToken(refresh);
      return access;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 &&
          await tokenStorage.getRefreshToken() == previous) {
        await tokenStorage.clearTokens();
      }
      return null;
    } finally {
      refreshDio.close();
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra['authRetried'] == true ||
        options.uri.path.contains('/auth/')) {
      handler.next(err);
      return;
    }
    try {
      final current = await tokenStorage.getAccessToken();
      String? token;
      if (current != null &&
          options.headers['Authorization'] != 'Bearer $current') {
        token = current; // Another request already rotated the session.
      } else {
        _refreshFuture ??= _refresh().whenComplete(() {
          _refreshFuture = null;
        });
        token = await _refreshFuture;
      }
      if (token == null) {
        handler.next(err);
        return;
      }
      options.extra['authRetried'] = true;
      options.headers['Authorization'] = 'Bearer $token';
      // Retry is bounded and occurs after refresh completes, so a second 401
      // cannot queue itself and deadlock all pending requests.
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}
