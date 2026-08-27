import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../config/constants.dart';

/// Whether crash reporting is active (a SENTRY_DSN was provided at build time).
bool get crashReportingEnabled => AppConstants.sentryDsn.isNotEmpty;

/// Centralised reporting hook for uncaught errors. Forwards to Sentry when a
/// SENTRY_DSN is provided (--dart-define); otherwise a no-op-friendly wrapper so
/// the app still runs without it. Always prints in non-release builds.
///
/// `main.dart` dışındaki katmanlar da (ör. açılış ekranı) aynı hattı kullansın
/// diye buraya taşındı; davranış birebir korunur.
void reportError(Object error, StackTrace? stack) {
  if (crashReportingEnabled) {
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
