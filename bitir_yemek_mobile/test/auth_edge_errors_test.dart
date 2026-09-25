import 'dart:convert';
import 'dart:typed_data';

import 'package:bitir_yemek_mobile/core/network/dio_client.dart';
import 'package:bitir_yemek_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bitir_yemek_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'security_test.dart' show MemoryTokens;

class _EdgeAdapter implements HttpClientAdapter {
  int status = 429;
  String body = 'error code: 1015\n';
  String contentType = 'text/plain';
  List<String>? retryAfter;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [contentType],
      'Retry-After': ?retryAfter,
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late DioClient client;
  late _EdgeAdapter edge;
  late AuthRemoteDataSource source;

  setUp(() {
    client = DioClient();
    edge = _EdgeAdapter();
    client.dio.httpClientAdapter = edge;
    source = AuthRemoteDataSource(dioClient: client);
  });
  tearDown(() => client.dio.close(force: true));

  const retryMessage =
      'Çok fazla deneme yaptınız. Lütfen biraz bekleyip tekrar deneyin.';

  test(
    'plain-text edge 429 is a safe auth error for every login method',
    () async {
      final requests = [
        () => source.requestOtp('customer@example.test'),
        () => source.verifyOtp(email: 'customer@example.test', code: '123456'),
        () => source.refreshToken('test-refresh-token'),
        () => source.googleLogin(idToken: 'test-google-token'),
        () => source.appleLogin(
          identityToken: 'test-apple-token',
          userIdentifier: 'test-user',
        ),
      ];
      for (final request in requests) {
        await expectLater(
          request(),
          throwsA(
            isA<AuthException>()
                .having((e) => e.statusCode, 'status', 429)
                .having((e) => e.message, 'message', retryMessage),
          ),
        );
      }
    },
  );

  test(
    'Retry-After reaches OTP UI results without technical cast errors',
    () async {
      edge.retryAfter = ['10'];
      final repository = AuthRepositoryImpl(
        remoteDataSource: source,
        tokenStorage: MemoryTokens(),
      );
      const message =
          'Çok fazla deneme yaptınız. Lütfen 10 saniye sonra tekrar deneyin.';
      final requested = await repository.requestOtp('customer@example.test');
      final verified = await repository.verifyOtp(
        email: 'customer@example.test',
        code: '123456',
      );
      expect(requested.isSuccess, isFalse);
      expect(requested.error, message);
      expect(verified.isSuccess, isFalse);
      expect(verified.error, message);
    },
  );

  test(
    'missing or unsupported Retry-After values use a generic retry message',
    () async {
      for (final header in <List<String>?>[
        null,
        ['0'],
        ['-10'],
        ['0x10'],
        ['invalid'],
        ['Wed, 21 Oct 2015 07:28:00 GMT'],
        ['10', '20'],
      ]) {
        edge.retryAfter = header;
        await expectLater(
          source.requestOtp('customer@example.test'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              retryMessage,
            ),
          ),
        );
      }
    },
  );

  test(
    'HTML and non-object JSON errors do not leak technical responses',
    () async {
      edge.status = 503;
      for (final (contentType, body) in [
        ('text/html', '<html>Origin unavailable</html>'),
        ('text/plain', 'upstream failure'),
        ('application/json', 'null'),
        ('application/json', '42'),
        ('application/json', '[]'),
        ('application/json', '{"message":42,"errors":{}}'),
      ]) {
        edge.contentType = contentType;
        edge.body = body;
        await expectLater(
          source.requestOtp('customer@example.test'),
          throwsA(
            isA<AuthException>()
                .having((e) => e.statusCode, 'status', 503)
                .having(
                  (e) => e.message,
                  'message',
                  'Bir hata oluştu. Lütfen tekrar deneyin.',
                ),
          ),
        );
      }
    },
  );

  test('API credential and validation messages retain their meaning', () async {
    edge.status = 401;
    edge.contentType = 'application/json';
    edge.body = jsonEncode({
      'message': 'Giriş kodu geçersiz veya süresi dolmuş.',
      'errors': [
        {'message': 'Yeni bir giriş kodu isteyin.'},
        'E-posta adresinizi kontrol edin.',
        {'message': null},
        42,
      ],
    });
    await expectLater(
      source.verifyOtp(email: 'customer@example.test', code: '123456'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.statusCode, 'status', 401)
            .having(
              (e) => e.message,
              'message',
              'Giriş kodu geçersiz veya süresi dolmuş.',
            )
            .having((e) => e.errors, 'errors', [
              'Yeni bir giriş kodu isteyin.',
              'E-posta adresinizi kontrol edin.',
            ]),
      ),
    );
  });
}
