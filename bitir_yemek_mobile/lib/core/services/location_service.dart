import 'package:geolocator/geolocator.dart';

/// Konum yardımcıları. Tekil (singleton): `LocationService()` her zaman aynı
/// örneği döndürür; tekrar tekrar kurulum maliyeti olmaz.
class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  static const _platformTimeout = Duration(seconds: 2);
  static const _positionTimeout = Duration(seconds: 4);

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled().timeout(
      _platformTimeout,
    );
  }

  /// Check current location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission().timeout(_platformTimeout);
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current position.
  ///
  /// Gıda pazaryeri için ~100m hassasiyet yeterli olduğundan `medium` doğruluk
  /// kullanılır — `high` (tam GPS fix bekleme) açılışı belirgin yavaşlatır.
  /// Açılışta [preferRecent] yakın zamanda alınmış, yeterince hassas bir
  /// konumu kullanır. Kullanıcının açık konum-yenileme isteği taze ölçüm alır.
  Future<Position?> getCurrentPosition({bool preferRecent = false}) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permission
      LocationPermission permission = await checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      if (preferRecent) {
        try {
          final recent = await Geolocator.getLastKnownPosition().timeout(
            const Duration(milliseconds: 500),
          );
          final age = recent == null
              ? null
              : DateTime.now().difference(recent.timestamp);
          if (recent != null &&
              age != null &&
              !age.isNegative &&
              age <= const Duration(minutes: 2) &&
              recent.accuracy >= 0 &&
              recent.accuracy <= 200) {
            return recent;
          }
        } catch (_) {
          // Last-known konum her platformda bulunmayabilir; taze ölçümü dene.
        }
      }

      // Kapalı mekânda süresiz beklemek yerine mevcut konum seçme ekranına
      // geri dönülür. Android eklentisi timeLimit ile GPS isteğini de iptal eder.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _positionTimeout,
      ).timeout(_positionTimeout);
    } catch (e) {
      return null;
    }
  }

  /// Check if we have location permission
  Future<bool> hasPermission() async {
    final permission = await checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
