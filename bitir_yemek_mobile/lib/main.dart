import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'core/utils/error_reporter.dart';
import 'features/splash/presentation/pages/splash_page.dart';

/// Logs BLoC errors centrally so a thrown event handler is observable.
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    reportError(error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}

/// App initialisation (framework hooks, locale, Mapbox) + runApp.
Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forward all Flutter framework errors to our reporting hook.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    reportError(details.exception, details.stack);
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
  if (crashReportingEnabled) {
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
      (error, stack) => reportError(error, stack),
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
      home: const SplashPage(),
    );
  }
}
