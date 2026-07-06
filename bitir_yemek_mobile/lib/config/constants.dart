import 'package:flutter/foundation.dart';

class AppConstants {
  // API Configuration - Environment-aware
  // Release builds default to the production HTTPS backend (Railway/VPS).
  // Debug builds default to the local dev backend so `flutter run` works
  // out of the box without --dart-define. Override either with:
  //   --dart-define=API_BASE_URL=https://<vps-domain>/api
  // Local-dev default by platform: iOS simulator -> localhost,
  // Android emulator -> 10.0.2.2 (host loopback), physical device -> Mac LAN IP.
  static const String _prodBaseUrl =
      'https://api.bitirgitsin.com/api';
  static const String _devBaseUrl = 'http://localhost:3000/api';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode ? _devBaseUrl : _prodBaseUrl,
  );
  static const String apiVersion = 'v1';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String userRoleKey = 'user_role';

  // Pagination
  static const int defaultPageSize = 10;

  // Timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Mapbox - pass via: --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  // Google OAuth Client ID - pass via: --dart-define=GOOGLE_CLIENT_ID=xxx
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  // Sentry crash reporting - pass via: --dart-define=SENTRY_DSN=https://...
  // Empty => crash reporting disabled (the app runs normally without it).
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
