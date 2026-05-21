class AppConstants {
  // API Configuration - Environment-aware
  // Use --dart-define=API_BASE_URL=https://api.bitiryemek.com/api for production builds
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://yemek-app-backend-production.up.railway.app/api',
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
}
