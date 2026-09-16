import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/core/network/dio_client.dart';
import 'package:bitir_yemek_mobile/core/storage/token_storage.dart';
import 'package:bitir_yemek_mobile/features/payment/data/models/payment_status_model.dart';

class MemoryTokens implements TokenStorage {
  String? access = 'old-access';
  String? refresh = 'old-refresh';
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveAccessToken(String token) async {
    access = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refresh = token;
  }

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }

  @override
  Future<String?> getUserData() async => null;
  @override
  Future<String?> getUserRole() async => null;
  @override
  Future<void> saveUserData(String json) async {}
  @override
  Future<void> saveUserRole(String role) async {}
}

void main() {
  late HttpServer server;
  late MemoryTokens storage;
  late DioClient client;
  int refreshes = 0;
  String? revoked;
  bool alwaysUnauthorized = false;

  setUp(() async {
    storage = MemoryTokens();
    refreshes = 0;
    revoked = null;
    alwaysUnauthorized = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = DioClient(tokenStorage: storage);
    client.dio.options.baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/auth/refresh') {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        request.response.write(
          jsonEncode({
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          }),
        );
      } else if (request.uri.path == '/auth/logout') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        revoked = body['refreshToken'] as String?;
        request.response.write('{}');
      } else if (alwaysUnauthorized ||
          request.headers.value('Authorization') != 'Bearer new-access') {
        request.response.statusCode = 401;
        request.response.write('{}');
      } else {
        request.response.write('{"ok":true}');
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    client.dio.close(force: true);
    await server.close(force: true);
  });

  test(
    'concurrent 401s share one refresh and both requests complete',
    () async {
      final responses = await Future.wait([
        client.dio.get('/resource'),
        client.dio.get('/resource'),
      ]).timeout(const Duration(seconds: 3));
      expect(responses.every((r) => r.statusCode == 200), isTrue);
      expect(refreshes, 1);
      expect(storage.refresh, 'new-refresh');
    },
  );

  test(
    'a second 401 terminates instead of deadlocking the retry queue',
    () async {
      alwaysUnauthorized = true;
      await expectLater(
        client.dio.get('/resource').timeout(const Duration(seconds: 3)),
        throwsA(isA<DioException>()),
      );
      expect(refreshes, 1);
    },
  );

  test('failed login does not refresh an unrelated existing session', () async {
    alwaysUnauthorized = true;
    await expectLater(
      client.dio.post('/auth/login'),
      throwsA(isA<DioException>()),
    );
    expect(refreshes, 0);
  });

  test(
    'logout revokes the server token and clears local credentials',
    () async {
      await client.logout();
      expect(revoked, 'old-refresh');
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
    },
  );

  test(
    'cancelled paid order awaiting refund is never reported as a reservation success',
    () {
      final payment = PaymentStatusModel.fromJson({
        'paymentStatus': 'paid',
        'status': 'cancelled',
      });
      expect(payment.isPaid, isFalse);
      expect(payment.isFailed, isTrue);
    },
  );
}
