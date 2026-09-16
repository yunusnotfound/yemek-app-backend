import 'package:bitir_yemek_mobile/config/constants.dart';
import 'package:flutter_test/flutter_test.dart';

// The same tests run with explicit --dart-define overrides to verify both
// ordinary simulator launches and opt-in local development configuration.
void main() {
  test(
    'API endpoint defaults to live and honors explicit build configuration',
    () {
      const expected = String.fromEnvironment(
        'EXPECTED_API_BASE_URL',
        defaultValue: 'https://api.bitirgitsin.com/api',
      );
      expect(AppConstants.baseUrl, expected);
    },
  );

  test(
    'catalog refresh respects the configured interval and its lower bound',
    () {
      const expected = int.fromEnvironment(
        'EXPECTED_CATALOG_REFRESH_SECONDS',
        defaultValue: 15,
      );
      expect(AppConstants.catalogRefreshSeconds, expected);
      expect(AppConstants.catalogRefreshSeconds, greaterThanOrEqualTo(15));
    },
  );
}
