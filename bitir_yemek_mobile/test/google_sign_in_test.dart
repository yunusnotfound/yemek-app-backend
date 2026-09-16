import 'dart:convert';

import 'package:bitir_yemek_mobile/core/network/dio_client.dart';
import 'package:bitir_yemek_mobile/core/storage/onboarding_storage.dart';
import 'package:bitir_yemek_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bitir_yemek_mobile/features/auth/data/google_sign_in_config.dart';
import 'package:bitir_yemek_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'security_test.dart' show MemoryTokens;

// Exercise the real GoogleSignIn/GoogleSignInPlatform code. Only the native
// channel and HTTP boundary are replaced; no Google accounts or API are used.
class _GoogleNativeBoundary {
  static const channel = MethodChannel('plugins.flutter.io/google_sign_in');
  final calls = <MethodCall>[];
  String? idToken = 'signed-provider-id-token';
  bool cancelled = false;
  PlatformException? signInError;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'init':
        return null;
      case 'signIn':
        if (signInError != null) throw signInError!;
        if (cancelled) return null;
        return <String, Object?>{
          'id': 'provider-user-id',
          'email': 'google-user@example.test',
          'displayName': 'Google User',
        };
      case 'getTokens':
        return <String, Object?>{
          'idToken': idToken,
          'accessToken': 'provider-access-token-must-not-go-to-api',
        };
      default:
        throw StateError('Unexpected Google native call: ${call.method}');
    }
  }

  Map<Object?, Object?> get initializedWith =>
      calls.singleWhere((call) => call.method == 'init').arguments as Map;
}

class _GoogleApiBoundary implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Map<String, Object?> response = {
    'accessToken': 'app-access-token',
    'refreshToken': 'app-refresh-token',
    'user': {
      'id': 'app-user-id',
      'email': 'google-user@example.test',
      'name': 'Google User',
      'role': 'customer',
      'isEmailVerified': true,
    },
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RememberedTokens extends MemoryTokens {
  String? userRole;
  String? userData;

  @override
  Future<void> saveUserRole(String role) async => userRole = role;

  @override
  Future<void> saveUserData(String json) async => userData = json;
}

class _MemoryOnboarding implements OnboardingStorage {
  bool marked = false;

  @override
  Future<bool> hasSignedInBefore() async => marked;

  @override
  Future<void> markSignedIn() async => marked = true;
}

GoogleSignIn _configuredGoogle({
  TargetPlatform platform = TargetPlatform.iOS,
  bool isWeb = false,
  String ios = '',
  String server = '',
  String legacy = '',
}) => createGoogleSignIn(
  platform: platform,
  isWeb: isWeb,
  iosClientId: ios,
  serverClientId: server,
  legacyClientId: legacy,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _GoogleNativeBoundary native;

  setUp(() {
    native = _GoogleNativeBoundary();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_GoogleNativeBoundary.channel, native.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_GoogleNativeBoundary.channel, null);
  });

  group('Google OAuth platform configuration', () {
    test(
      'legacy iOS uses native plist IDs without a server audience override',
      () async {
        await _configuredGoogle(legacy: 'legacy-ios-client').signIn();

        expect(native.initializedWith['clientId'], isNull);
        expect(native.initializedWith['serverClientId'], isNull);
        expect(native.initializedWith['scopes'], ['email', 'profile']);
      },
    );

    test(
      'iOS forwards distinct native and backend clients to the SDK',
      () async {
        await _configuredGoogle(
          ios: ' ios-client ',
          server: ' web-server-client ',
          legacy: 'legacy-client-must-not-override',
        ).signIn();

        expect(native.initializedWith['clientId'], 'ios-client');
        expect(native.initializedWith['serverClientId'], 'web-server-client');
      },
    );

    test('iOS rejects a server client without an explicit native client', () {
      expect(
        () => _configuredGoogle(ios: '  ', server: 'web-server-client'),
        throwsA(isA<GoogleSignInConfigurationException>()),
      );
      expect(native.calls, isEmpty);
    });

    test('iOS rejects reusing its native client as the server audience', () {
      expect(
        () => _configuredGoogle(ios: ' ios-client ', server: 'ios-client'),
        throwsA(isA<GoogleSignInConfigurationException>()),
      );
      expect(native.calls, isEmpty);
    });

    test('Android keeps its legacy server audience fallback', () async {
      await _configuredGoogle(
        platform: TargetPlatform.android,
        legacy: 'legacy-web-client',
        ios: 'ios-client-must-not-be-used',
      ).signIn();

      expect(native.initializedWith['clientId'], isNull);
      expect(native.initializedWith['serverClientId'], 'legacy-web-client');
    });

    test('Android gives the explicit server client priority', () async {
      await _configuredGoogle(
        platform: TargetPlatform.android,
        server: 'explicit-web-client',
        legacy: 'legacy-web-client',
      ).signIn();

      expect(native.initializedWith['clientId'], isNull);
      expect(native.initializedWith['serverClientId'], 'explicit-web-client');
    });

    for (final useExplicitServer in [true, false]) {
      test(
        'Web supplies only clientId (explicit: $useExplicitServer)',
        () async {
          await _configuredGoogle(
            isWeb: true,
            server: useExplicitServer ? 'explicit-web-client' : '',
            legacy: 'legacy-web-client',
          ).signIn();

          expect(
            native.initializedWith['clientId'],
            useExplicitServer ? 'explicit-web-client' : 'legacy-web-client',
          );
          expect(native.initializedWith['serverClientId'], isNull);
        },
      );
    }
  });

  group('Google login session exchange', () {
    late _RememberedTokens tokens;
    late _MemoryOnboarding onboarding;
    late _GoogleApiBoundary api;
    late DioClient client;
    late AuthRepositoryImpl repository;

    setUp(() {
      tokens = _RememberedTokens();
      onboarding = _MemoryOnboarding();
      api = _GoogleApiBoundary();
      client = DioClient(tokenStorage: tokens);
      client.dio.options.baseUrl = 'https://api.example.test';
      client.dio.httpClientAdapter = api;
      repository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(dioClient: client),
        tokenStorage: tokens,
        onboardingStorage: onboarding,
        googleSignIn: _configuredGoogle(
          ios: 'ios-client',
          server: 'web-server-client',
        ),
      );
    });

    tearDown(() => client.dio.close(force: true));

    void expectSessionUntouched() {
      expect(tokens.access, 'old-access');
      expect(tokens.refresh, 'old-refresh');
      expect(tokens.userData, isNull);
      expect(tokens.userRole, isNull);
      expect(onboarding.marked, isFalse);
    }

    test('exchanges only the ID token and saves the backend session', () async {
      final result = await repository.googleLogin(role: 'business_owner');

      expect(result.isSuccess, isTrue);
      expect(result.user?.id, 'app-user-id');
      expect(native.initializedWith['clientId'], 'ios-client');
      expect(native.initializedWith['serverClientId'], 'web-server-client');
      expect(api.requests, hasLength(1));
      expect(api.requests.single.path, '/auth/google');
      expect(api.requests.single.data, {
        'idToken': 'signed-provider-id-token',
        'role': 'business_owner',
      });
      expect(tokens.access, 'app-access-token');
      expect(tokens.refresh, 'app-refresh-token');
      // The server owns the user's actual role, independent of signup intent.
      expect(tokens.userRole, 'customer');
      expect(jsonDecode(tokens.userData!)['id'], 'app-user-id');
      expect(onboarding.marked, isTrue);
    });

    for (final invalidToken in <String?>[null, '', '   ']) {
      test(
        'missing or blank ID token never reaches the API ($invalidToken)',
        () async {
          native.idToken = invalidToken;

          final result = await repository.googleLogin(role: 'customer');

          expect(result.isSuccess, isFalse);
          expect(result.error, 'Google kimlik doğrulama başarısız');
          expect(api.requests, isEmpty);
          expectSessionUntouched();
        },
      );
    }

    test(
      'cancelling Google sign-in preserves the previous app session',
      () async {
        native.cancelled = true;

        final result = await repository.googleLogin(role: 'customer');

        expect(result.isSuccess, isFalse);
        expect(result.error, 'Google ile giriş iptal edildi');
        expect(api.requests, isEmpty);
        expect(
          native.calls.map((call) => call.method),
          isNot(contains('getTokens')),
        );
        expectSessionUntouched();
      },
    );

    test(
      'backend auth rejection stays actionable without refreshing a session',
      () async {
        api.status = 401;
        api.response = {'message': 'Doğrulanmış Google hesabı gerekli'};

        final result = await repository.googleLogin(role: 'customer');

        expect(result.isSuccess, isFalse);
        expect(result.error, 'Doğrulanmış Google hesabı gerekli');
        expect(api.requests.map((request) => request.path), ['/auth/google']);
        expectSessionUntouched();
      },
    );

    test(
      'native configuration details are not exposed in a user error',
      () async {
        native.signInError = PlatformException(
          code: 'sign_in_failed',
          message: 'secret-debug-detail: private-client-token',
          details: {'nativeTrace': 'internal-sensitive-detail'},
        );

        final result = await repository.googleLogin(role: 'customer');

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('Google ile giriş tamamlanamadı'));
        expect(result.error, isNot(contains('private-client-token')));
        expect(result.error, isNot(contains('internal-sensitive-detail')));
        expect(result.error, isNot(contains('PlatformException')));
        expect(api.requests, isEmpty);
        expectSessionUntouched();
      },
    );

    test(
      'a native network failure explains how to retry without raw details',
      () async {
        native.signInError = PlatformException(
          code: 'network_error',
          message: 'internal-network-trace',
        );

        final result = await repository.googleLogin(role: 'customer');

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('İnternet bağlantınızı kontrol'));
        expect(result.error, isNot(contains('internal-network-trace')));
        expect(api.requests, isEmpty);
        expectSessionUntouched();
      },
    );
  });
}
