import 'dart:async';

import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/core/di/service_locator.dart';
import 'package:bitir_yemek_mobile/core/services/cache_service.dart';
import 'package:bitir_yemek_mobile/features/business_owner/presentation/pages/business_owner_scaffold.dart';
import 'package:bitir_yemek_mobile/features/location/presentation/pages/location_permission_page.dart';
import 'package:bitir_yemek_mobile/features/location/presentation/pages/manual_location_page.dart';
import 'package:bitir_yemek_mobile/features/main/presentation/pages/main_scaffold.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class _FakeGeocoder extends GeocodingPlatform {
  final queries = <String>[];
  Completer<List<Location>>? pending;
  bool empty = false;
  bool fail = false;

  @override
  Future<List<Location>> locationFromAddress(String address) async {
    queries.add(address);
    if (fail) throw StateError('Unavailable');
    if (pending != null) return pending!.future;
    if (empty) return [];
    return [
      Location(latitude: 40.991, longitude: 29.023, timestamp: DateTime(2026)),
    ];
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async => [
    const Placemark(
      locality: 'Kadıköy',
      administrativeArea: 'İstanbul',
      country: 'Türkiye',
    ),
  ];
}

class _FakeGps extends GeolocatorPlatform {
  int permissionRequests = 0;
  Completer<bool>? pendingEnabled;

  @override
  Future<bool> isLocationServiceEnabled() async =>
      pendingEnabled?.future ?? true;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return LocationPermission.deniedForever;
  }
}

void main() {
  final originalGps = GeolocatorPlatform.instance;
  final originalGeocoder = GeocodingPlatform.instance;
  late _FakeGeocoder geocoder;
  late _FakeGps gps;
  final requests = <RequestOptions>[];

  setUp(() {
    gps = _FakeGps();
    geocoder = _FakeGeocoder();
    GeolocatorPlatform.instance = gps;
    GeocodingPlatform.instance = geocoder;
    CacheService().clear();
    requests.clear();
    appDioClient.dio.interceptors.clear();
    appDioClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          // All app requests are resolved locally; no backend or map service runs.
          if (request.path.startsWith('/business-dashboard/')) {
            handler.reject(
              DioException(
                requestOptions: request,
                response: Response(
                  requestOptions: request,
                  statusCode: 503,
                  data: {'message': 'Test yanıtı'},
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'categories': [],
                'packages': [],
                'favorites': [],
                'coupons': [],
                'pagination': {
                  'page': 1,
                  'limit': 10,
                  'total': 0,
                  'totalPages': 1,
                },
              },
            ),
          );
        },
      ),
    );
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGps;
    if (originalGeocoder != null) GeocodingPlatform.instance = originalGeocoder;
    appDioClient.dio.interceptors.clear();
    CacheService().clear();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byType(TextField),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'Kadıköy, İstanbul');
    await tester.scrollUntilVisible(
      find.text('Bölgeyi ara'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bölgeyi ara'));
    await tester.pumpAndSettle();
  }

  testWidgets('GPS denied users choose a region and enter nearby discovery', (
    tester,
  ) async {
    await mount(tester, const LocationPermissionPage());
    await tester.tap(find.text('Mevcut konumumu kullan'));
    await tester.pumpAndSettle();
    expect(gps.permissionRequests, 1);
    expect(find.byType(LocationPermissionPage), findsOneWidget);
    await tester.tap(find.text('Konum seç'));
    await tester.pumpAndSettle();
    await search(tester);
    await tester.tap(find.text('Kadıköy, İstanbul, Türkiye'));
    await tester.pumpAndSettle();
    final scaffold = tester.widget<MainScaffold>(find.byType(MainScaffold));
    expect(scaffold.latitude, 40.991);
    expect(scaffold.longitude, 29.023);
    expect(find.byType(LocationPermissionPage), findsNothing);
    expect(gps.permissionRequests, 1);
    expect(geocoder.queries.single, 'Kadıköy, İstanbul, Türkiye');
    expect(
      requests.any(
        (request) =>
            request.path == '/packages' &&
            request.queryParameters['lat'] == 40.991 &&
            request.queryParameters['lng'] == 29.023,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual location preserves the business owner destination', (
    tester,
  ) async {
    await mount(tester, const LocationPermissionPage(isBusinessOwner: true));
    await tester.tap(find.text('Konum seç'));
    await tester.pumpAndSettle();
    await search(tester);
    await tester.tap(find.text('Kadıköy, İstanbul, Türkiye'));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessOwnerScaffold), findsOneWidget);
    expect(find.byType(MainScaffold), findsNothing);
    expect(gps.permissionRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual picker cancellation leaves permission choices usable', (
    tester,
  ) async {
    await mount(tester, const LocationPermissionPage());
    await tester.tap(find.text('Konum seç'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    final select = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Konum seç'),
    );
    expect(select.onPressed, isNotNull);
    await tester.tap(find.text('Konum seç'));
    await tester.pumpAndSettle();
    expect(find.byType(ManualLocationPage), findsOneWidget);
    expect(gps.permissionRequests, 0);
  });

  testWidgets(
    'region validation, empty results and connection errors allow retry',
    (tester) async {
      await mount(tester, const ManualLocationPage());
      await tester.tap(find.text('Bölgeyi ara'));
      await tester.pumpAndSettle();
      expect(find.textContaining('en az 3 karakterle'), findsOneWidget);
      expect(geocoder.queries, isEmpty);
      geocoder.empty = true;
      await search(tester);
      expect(find.textContaining('Bölge bulunamadı'), findsOneWidget);
      geocoder.fail = true;
      await search(tester);
      expect(find.textContaining('Bağlantını kontrol'), findsOneWidget);
      geocoder.fail = geocoder.empty = false;
      await search(tester);
      expect(find.text('Kadıköy, İstanbul, Türkiye'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Beşiktaş');
      await tester.pump();
      expect(find.text('Kadıköy, İstanbul, Türkiye'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GPS completion after leaving does not use disposed state', (
    tester,
  ) async {
    gps.pendingEnabled = Completer<bool>();
    await mount(tester, const LocationPermissionPage());
    await tester.tap(find.text('Mevcut konumumu kullan'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    gps.pendingEnabled!.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(gps.permissionRequests, 0);
  });

  testWidgets('search completion after leaving does not use disposed state', (
    tester,
  ) async {
    geocoder.pending = Completer<List<Location>>();
    await mount(tester, const ManualLocationPage());
    await tester.enterText(find.byType(TextField), 'Kadıköy');
    await tester.tap(find.text('Bölgeyi ara'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    geocoder.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission and search pages fit small screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, const LocationPermissionPage(), textScale: 2);
    await tester.ensureVisible(find.text('Konum seç'));
    await tester.tap(find.text('Konum seç'));
    await tester.pumpAndSettle();
    await search(tester);
    await tester.scrollUntilVisible(
      find.text('Kadıköy, İstanbul, Türkiye'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Kadıköy, İstanbul, Türkiye'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
