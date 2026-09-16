import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../config/constants.dart';

class GoogleSignInConfigurationException implements Exception {
  const GoogleSignInConfigurationException();

  String get message =>
      'Google ile giriş ayarları eksik. Şimdilik e-posta ile giriş yapabilirsiniz.';
}

/// A native OAuth client and a web/server OAuth client are different clients.
/// Leaving iOS IDs unset lets the SDK use GIDClientID/GIDServerClientID from
/// Info.plist. In the existing native-only setup the token keeps its native
/// audience, which the backend already verifies.
GoogleSignIn createGoogleSignIn({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
  String iosClientId = AppConstants.googleIosClientId,
  String serverClientId = AppConstants.googleServerClientId,
  String legacyClientId = AppConstants.googleClientId,
}) {
  String? configured(String value) =>
      value.trim().isEmpty ? null : value.trim();
  final target = platform ?? defaultTargetPlatform;
  final server = configured(serverClientId);
  final legacy = configured(legacyClientId);
  final ios = configured(iosClientId);

  // The installed iOS plugin only applies a Dart server ID when a Dart native
  // client ID is also present; otherwise it silently falls back to Info.plist.
  if (!isWeb &&
      target == TargetPlatform.iOS &&
      server != null &&
      (ios == null || ios == server)) {
    throw const GoogleSignInConfigurationException();
  }

  return GoogleSignIn(
    clientId: isWeb
        ? server ?? legacy
        : target == TargetPlatform.iOS
        ? ios
        : null,
    serverClientId: isWeb
        ? null
        : server ?? (target == TargetPlatform.android ? legacy : null),
    scopes: const ['email', 'profile'],
  );
}
