// Real-device profile benchmark using production widgets and local fixtures.
// No production API, account, payment or remote image is contacted.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/core/di/service_locator.dart';
import 'package:bitir_yemek_mobile/features/coupons/presentation/coupons_page.dart';
import 'package:bitir_yemek_mobile/features/coupons/presentation/coupon_tile.dart';
import 'package:bitir_yemek_mobile/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/domain/repositories/businesses_repository.dart';
import 'package:bitir_yemek_mobile/features/home/data/repositories/businesses_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/package_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/category_model.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/packages_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/pages/home_page.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/pages/all_packages_page.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/package_card.dart';

const _categories = [
  CategoryModel(id: 0, name: 'Hepsi', slug: 'all'),
  CategoryModel(id: 1, name: 'Fırın', slug: 'firin-pastane'),
  CategoryModel(id: 2, name: 'Kafe', slug: 'kafe'),
  CategoryModel(id: 3, name: 'Manav', slug: 'manav'),
];

class _FixtureBusinesses implements BusinessesRepository {
  _FixtureBusinesses(this.packages);
  final List<PackageModel> packages;
  int refreshes = 0;

  @override
  Future<PackagesResult> getNearbyPackages({
    required double latitude,
    required double longitude,
    double radius = 5,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
    String? categoryId,
  }) async {
    refreshes++;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return PackagesResult.success(
      packages: packages,
      pagination: PaginationModel(
        page: 1,
        totalPages: 1,
        limit: packages.length,
        total: packages.length,
      ),
    );
  }

  @override
  Future<CategoriesResult> getCategories({bool forceRefresh = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return CategoriesResult.success(categories: _categories);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected repository request: ${invocation.memberName}',
  );
}

class _NoNetworkFavorites implements FavoritesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected favorites mutation: ${invocation.memberName}',
  );
}

class _ReadyHome extends HomeBloc {
  _ReadyHome(BusinessesRepository repository) : super(repository: repository) {
    emit(const HomeLoaded(categories: _categories));
  }
}

class _ReadyPackages extends PackagesBloc {
  _ReadyPackages(_FixtureBusinesses repository)
    : super(repository: repository) {
    final packages = repository.packages;
    emit(
      PackagesLoaded(
        packages: packages,
        hasReachedMax: true,
        pagination: PaginationModel(
          page: 1,
          totalPages: 1,
          limit: packages.length,
          total: packages.length,
        ),
      ),
    );
  }
}

class _WalletFixture implements HttpClientAdapter {
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path != '/coupons/mine') {
      throw StateError('Unexpected API request ${options.path}');
    }
    requests++;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return ResponseBody.fromString(
      jsonEncode({
        'coupons': List.generate(
          100,
          (i) => {
            'id': 'campaign-$i',
            'code': 'TEST$i',
            'title': 'Mahallenden bir fırsat $i',
            'discountType': 'fixed',
            'discountValue': 50,
            'minOrderAmount': 250,
            'firstOrderOnly': false,
            'perUserLimit': 1,
            'businessIds': <String>[],
            'expiresAt': '2030-12-31T20:59:59Z',
            'eligible': true,
          },
        ),
        'savings': {'totalSaved': 350, 'rescuedPackages': 7},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final adapter = _WalletFixture();
  HttpServer? imageServer;
  int imageRequests = 0;
  late String imageBase;
  final frames = <FrameTiming>[];
  void collect(List<FrameTiming> batch) => frames.addAll(batch);

  setUpAll(() async {
    expect(
      kProfileMode || const bool.fromEnvironment('PERF_ALLOW_DEBUG'),
      isTrue,
      reason: 'Use --profile on a physical phone for performance results.',
    );
    appDioClient.dio.interceptors.clear();
    appDioClient.dio.httpClientAdapter = adapter;
    // Avoid native reverse-geocoding requests while profiling local rendering.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geocoding'),
          (call) async => [
            {
              'name': 'Test',
              'street': 'Moda',
              'locality': 'Kadıköy',
              'subLocality': 'Moda',
              'administrativeArea': 'İstanbul',
              'country': 'Türkiye',
              'isoCountryCode': 'TR',
              'postalCode': '34710',
              'subAdministrativeArea': 'Kadıköy',
              'thoroughfare': 'Test',
              'subThoroughfare': '1',
            },
          ],
        );
    final image = await rootBundle.load('assets/images/food_box.png');
    imageServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    imageBase = 'http://127.0.0.1:${imageServer!.port}';
    imageServer!.listen((request) async {
      imageRequests++;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(image.buffer.asUint8List());
      await request.response.close();
    });
    binding.reportData = {
      'complete': false,
      'environment': {
        'profileMode': kProfileMode,
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'logicalCores': Platform.numberOfProcessors,
        'displayHz': PlatformDispatcher.instance.displays.first.refreshRate,
        'framePolicy': 'fullyLive',
        'fixtureLatencyMs': 150,
        'packages': 80,
        'coupons': 100,
        'scope':
            'real production widgets; local synthetic API/images; no end-to-end backend/native map timing',
      },
    };
  });

  tearDownAll(() async {
    await imageServer?.close(force: true);
    // Console fallback for profile devices where wireless VM discovery fails.
    // One JSON entry per line avoids native console line-length truncation.
    for (final entry in (binding.reportData ?? <String, dynamic>{}).entries) {
      debugPrint(
        'PHONE_PERFORMANCE_RESULT ${jsonEncode({entry.key: entry.value})}',
      );
    }
  });

  List<PackageModel> packages() => List.generate(
    80,
    (i) => PackageModel.fromJson({
      'id': 'package-$i',
      'businessId': 'business-$i',
      'title': 'Günün sürpriz paketi $i',
      'originalPrice': 499,
      'discountedPrice': 149.9,
      'quantity': 10,
      'remainingQuantity': 7,
      'pickupDate': '2030-12-31',
      'pickupStart': '18:00',
      'pickupEnd': '21:00',
      'isActive': true,
      'imageUrl': '$imageBase/package-$i.png',
      'business': {
        'id': 'business-$i',
        'name': 'Mahalle Fırını $i',
        'address': 'Moda, Kadıköy',
        'latitude': 41.0,
        'longitude': 29.0,
        'rating': 4.8,
        'imageUrl': '$imageBase/logo-$i.png',
        'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin-pastane'},
      },
    }),
  );

  Future<void> measure(
    WidgetTester tester,
    String name,
    Future<void> Function() action,
  ) async {
    debugPrint('PHONE_PERFORMANCE_SCENE $name');
    frames.clear();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    binding.addTimingsCallback(collect);
    final clock = Stopwatch()..start();
    await action();
    clock.stop();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    binding.removeTimingsCallback(collect);
    expect(frames.length, greaterThan(0));
    final build =
        frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final raster =
        frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    double percentile(List<double> data, double p) =>
        data[(data.length * p).ceil() - 1];
    binding.reportData![name] = {
      'elapsedMs': clock.elapsedMilliseconds,
      'frames': frames.length,
      'buildP50Ms': percentile(build, .5),
      'buildP95Ms': percentile(build, .95),
      'buildMaxMs': build.last,
      'rasterP50Ms': percentile(raster, .5),
      'rasterP95Ms': percentile(raster, .95),
      'rasterMaxMs': raster.last,
      'over60HzBudgetCount': frames
          .where(
            (f) =>
                f.buildDuration.inMicroseconds > 16667 ||
                f.rasterDuration.inMicroseconds > 16667,
          )
          .length,
      'over120HzBudgetCount': frames
          .where(
            (f) =>
                f.buildDuration.inMicroseconds > 8333 ||
                f.rasterDuration.inMicroseconds > 8333,
          )
          .length,
      'rssMiB': ProcessInfo.currentRss / 1048576,
    };
    debugPrint('PHONE_PERFORMANCE_SCENE_DONE $name');
  }

  Future<void> scroll(
    WidgetTester tester,
    Finder finder, {
    int rounds = 8,
  }) async {
    for (var i = 0; i < rounds; i++) {
      await tester.fling(finder, Offset(0, i < rounds ~/ 2 ? -600 : 600), 1200);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    }
  }

  testWidgets('profile real discovery, package and coupon scrolling', (
    tester,
  ) async {
    final repository = _FixtureBusinesses(packages());
    final home = _ReadyHome(repository);
    final packageBloc = _ReadyPackages(repository);
    final favorites = FavoritesBloc(repository: _NoNetworkFavorites());
    addTearDown(home.close);
    addTearDown(packageBloc.close);
    addTearDown(favorites.close);
    Widget host(Widget child) => MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>.value(value: home),
        BlocProvider<PackagesBloc>.value(value: packageBloc),
        BlocProvider<FavoritesBloc>.value(value: favorites),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
    await measure(tester, 'home_first_render', () async {
      await tester.pumpWidget(
        host(const HomePage(latitude: 41, longitude: 29)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    });
    expect(find.byType(PackageCard), findsWidgets);
    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await measure(tester, 'home_scroll', () => scroll(tester, vertical.first));

    await measure(tester, 'packages_first_render', () async {
      await tester.pumpWidget(
        host(
          const AllPackagesView(
            title: 'Yakındaki paketler',
            latitude: 41,
            longitude: 29,
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    });
    expect(find.byType(PackageCard), findsWidgets);
    await measure(
      tester,
      'packages_scroll_cold_images',
      () => scroll(tester, find.byType(ListView).first, rounds: 16),
    );
    await measure(
      tester,
      'packages_scroll_warm_images',
      () => scroll(tester, find.byType(ListView).first, rounds: 16),
    );

    await measure(tester, 'coupons_first_render', () async {
      await tester.pumpWidget(
        host(const CouponsPage(latitude: 41, longitude: 29)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    });
    expect(find.byType(CouponTile), findsWidgets);
    await measure(
      tester,
      'coupons_scroll',
      () => scroll(tester, find.byType(ListView).first, rounds: 12),
    );
    expect(
      imageRequests,
      greaterThan(0),
      reason: 'Image decode paths must have actually run.',
    );
    expect(adapter.requests, greaterThan(0));
    binding.reportData!['fixtureRequests'] = {
      'images': imageRequests,
      'wallet': adapter.requests,
      'packageRefreshes': repository.refreshes,
    };
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    binding.reportData!['complete'] = true;
  });
}
