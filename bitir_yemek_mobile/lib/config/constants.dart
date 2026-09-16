class AppConstants {
  // Simulator and release builds use the same live backend by default.
  // Local development remains an explicit API_BASE_URL override.
  static const String _prodBaseUrl = 'https://api.bitirgitsin.com/api';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _prodBaseUrl,
  );
  static const String apiVersion = 'v1';

  // Refresh visible catalog data every 15 seconds unless explicitly overridden.
  static const int _configuredCatalogRefreshSeconds = int.fromEnvironment(
    'CATALOG_REFRESH_SECONDS',
    defaultValue: 15,
  );
  static const int catalogRefreshSeconds = _configuredCatalogRefreshSeconds < 15
      ? 15
      : _configuredCatalogRefreshSeconds;

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

  // Legacy web/server ID for Android and web. On iOS the native client comes
  // from Info.plist; it must not also be sent as an OAuth server audience.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  // Optional WEB OAuth client. If set, the backend GOOGLE_CLIENT_ID must match.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  // Sentry crash reporting - pass via: --dart-define=SENTRY_DSN=https://...
  // Empty => crash reporting disabled (the app runs normally without it).
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
