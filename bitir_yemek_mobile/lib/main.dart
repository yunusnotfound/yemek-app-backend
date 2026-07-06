import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'core/di/service_locator.dart';
import 'core/services/location_service.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/business_owner/presentation/pages/business_owner_scaffold.dart';
import 'features/location/presentation/pages/location_permission_page.dart';
import 'features/main/presentation/pages/main_scaffold.dart';

/// Whether crash reporting is active (a SENTRY_DSN was provided at build time).
bool get _crashReportingEnabled => AppConstants.sentryDsn.isNotEmpty;

/// Centralised reporting hook for uncaught errors. Forwards to Sentry when a
/// SENTRY_DSN is provided (--dart-define); otherwise a no-op-friendly wrapper so
/// the app still runs without it. Always prints in non-release builds.
void _reportError(Object error, StackTrace? stack) {
  if (_crashReportingEnabled) {
    // fire-and-forget; capture'ın kendi hatası uygulamayı etkilemesin.
    unawaited(
      Sentry.captureException(error, stackTrace: stack)
          .catchError((_) => SentryId.empty()),
    );
  }
  if (!kReleaseMode) {
    debugPrint('Uncaught error: $error');
    if (stack != null) debugPrintStack(stackTrace: stack);
  }
}

/// Logs BLoC errors centrally so a thrown event handler is observable.
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    _reportError(error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}

/// App initialisation (framework hooks, locale, Mapbox) + runApp.
Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forward all Flutter framework errors to our reporting hook.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _reportError(details.exception, details.stack);
  };

  Bloc.observer = AppBlocObserver();

  await initializeDateFormatting('tr_TR');

  // Initialize Mapbox SDK with access token (only if provided)
  if (AppConstants.mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
  }

  runApp(const MainApp());
}

Future<void> main() async {
  if (_crashReportingEnabled) {
    // Sentry kendi hata zone'unu + native crash yakalamayı kurar; uygulamayı
    // appRunner içinde başlatır.
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConstants.sentryDsn;
        options.environment = kReleaseMode ? 'production' : 'debug';
        options.tracesSampleRate = 0.0; // hata odaklı; APM istenirse artır
      },
      appRunner: _startApp,
    );
  } else {
    // Sentry yoksa mevcut davranış: async hataları runZonedGuarded yakalar.
    runZonedGuarded<Future<void>>(
      _startApp,
      (error, stack) => _reportError(error, stack),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitirGitsin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Any failure during these async reads (secure storage, location plugin)
    // must never leave the user stuck on the splash spinner. On error we fall
    // back to the WelcomePage (a safe, always-reachable destination).
    try {
      final locationService = LocationService();

      // Birbirinden bağımsız okumaları paralel yürüt — dönen kullanıcıda açılışı
      // hızlandırır (token, rol ve izin kontrolü ardışık beklemez).
      final results = await Future.wait([
        appTokenStorage.getAccessToken(),
        appTokenStorage.getUserRole(),
        locationService.hasPermission(),
      ]);
      final accessToken = results[0] as String?;
      final role = results[1] as String?;
      final hasPermission = results[2] as bool;

      if (accessToken == null || accessToken.isEmpty) {
        // No token — show welcome page
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WelcomePage()),
          );
        }
        return;
      }

      final isBusinessOwner = role == 'business_owner';

      if (hasPermission) {
        if (isBusinessOwner) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const BusinessOwnerScaffold(),
              ),
            );
          }
          return;
        }

        final position = await locationService.getCurrentPosition();
        if (position != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainScaffold(
                latitude: position.latitude,
                longitude: position.longitude,
              ),
            ),
          );
          return;
        }
      }

      // No location permission yet (or position unavailable)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                LocationPermissionPage(isBusinessOwner: isBusinessOwner),
          ),
        );
      }
    } catch (e, stack) {
      _reportError(e, stack);
      // Safe fallback so the user is never stranded on the spinner.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.eco, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            // App Name
            Text(
              'BitirGitsin',
              style: AppTypography.h2.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 48),
            // Loading Indicator
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
