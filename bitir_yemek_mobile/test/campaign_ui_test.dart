import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/core/di/service_locator.dart';
import 'package:bitir_yemek_mobile/features/coupons/presentation/coupons_page.dart';
import 'package:bitir_yemek_mobile/features/coupons/presentation/coupon_tile.dart';
import 'package:bitir_yemek_mobile/features/coupons/presentation/campaign_banner.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/package_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/reservation_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/datasources/businesses_remote_datasource.dart';
import 'package:bitir_yemek_mobile/features/home/data/repositories/businesses_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/reservation_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/reservation_confirm_sheet.dart';

import 'package:bitir_yemek_mobile/features/home/presentation/pages/home_page.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/packages_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/bottom_nav_bar.dart';
import 'package:bitir_yemek_mobile/features/home/domain/repositories/businesses_repository.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/category_model.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:bitir_yemek_mobile/features/favorites/domain/repositories/favorites_repository.dart';

class QuietBusinessRepository implements BusinessesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QuietFavoritesRepository implements FavoritesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewHome extends HomeBloc {
  PreviewHome() : super(repository: QuietBusinessRepository()) {
    emit(
      const HomeLoaded(
        categories: [
          CategoryModel(id: 0, name: 'Hepsi', slug: 'all'),
          CategoryModel(id: 1, name: 'Fırın', slug: 'firin-pastane'),
          CategoryModel(id: 2, name: 'Kafe', slug: 'kafe'),
          CategoryModel(id: 3, name: 'Manav', slug: 'manav'),
        ],
      ),
    );
  }
}

class PreviewPackages extends PackagesBloc {
  PreviewPackages() : super(repository: QuietBusinessRepository()) {
    emit(
      PackagesLoaded(
        packages: [package],
        pagination: const PaginationModel(
          page: 1,
          totalPages: 1,
          limit: 10,
          total: 1,
        ),
      ),
    );
  }
}

const offerJson = {
  'id': 'coupon',
  'code': 'ILK100',
  'title': 'İlk paketine özel',
  'discountType': 'fixed',
  'discountValue': 100,
  'minOrderAmount': 500,
  'firstOrderOnly': true,
  'perUserLimit': 1,
  'businessIds': ['business'],
  'expiresAt': '2026-12-31T20:59:59Z',
  'eligible': true,
};
const packageJson = {
  'id': 'package',
  'businessId': 'business',
  'title': 'Günün sürpriz paketi',
  'originalPrice': 850,
  'discountedPrice': 599.9,
  'quantity': 5,
  'remainingQuantity': 3,
  'pickupDate': '2026-09-09',
  'pickupStart': '18:00',
  'pickupEnd': '20:00',
  'isActive': true,
  'business': {
    'id': 'business',
    'name': 'Mahalle Fırını',
    'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin-pastane'},
    'address': 'Moda, Kadıköy',
    'rating': 4.8,
  },
};
final package = PackageModel.fromJson(packageJson);

class CampaignAdapter implements HttpClientAdapter {
  bool unavailable = false, empty = false;
  double unitPrice = 599.9;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final Object body;
    if (options.path == '/coupons/mine') {
      body = {
        'coupons': empty
            ? []
            : [
                {
                  ...offerJson,
                  'eligible': !unavailable,
                  if (unavailable) 'reason': 'İlk sipariş hakkınız kullanıldı',
                },
              ],
        'savings': {'totalSaved': 250.1, 'rescuedPackages': 1},
      };
    } else if (options.path == '/coupons/validate') {
      body = {
        'coupon': offerJson,
        'valid': true,
        'discountAmount': 100.0,
        'finalPrice':
            ((unitPrice * 100).round() *
                    ((options.data['quantity'] as int?) ?? 1) -
                10000) /
            100,
      };
    } else {
      body = {'cards': []};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void visualTest(String name, Future<void> Function(WidgetTester) test) {
  testWidgets(name, (tester) async {
    final previous = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await test(tester);
    } finally {
      debugDisableShadows = previous;
    }
  });
}

Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
  (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
      .markNeedsPaint();
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('/tmp/bitir-campaign-preview')
      ..createSync(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  final adapter = CampaignAdapter();
  setUp(() {
    adapter.calls.clear();
    adapter.unitPrice = 599.9;
    adapter.unavailable = false;
    adapter.empty = false;
    appDioClient.dio.interceptors.clear();
    appDioClient.dio.httpClientAdapter = adapter;
  });
  setUpAll(() async {
    final fonts = FontLoader('Korolev');
    for (final weight in ['Medium', 'Bold', 'Heavy']) {
      fonts.addFont(rootBundle.load('assets/fonts/Korolev $weight.otf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final scale in [1.0, 2.0]) {
    visualTest('Keşfet cards and campaign fit at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final home = PreviewHome();
      final packages = PreviewPackages();
      final favorites = FavoritesBloc(repository: QuietFavoritesRepository());
      addTearDown(home.close);
      addTearDown(packages.close);
      addTearDown(favorites.close);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: MultiBlocProvider(
              providers: [
                BlocProvider<HomeBloc>.value(value: home),
                BlocProvider<PackagesBloc>.value(value: packages),
                BlocProvider.value(value: favorites),
              ],
              child: Scaffold(
                body: const HomePage(latitude: 41, longitude: 29),
                bottomNavigationBar: BottomNavBar(
                  currentIndex: 0,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await shot(tester, key, scale == 1 ? 'kesfet' : 'kesfet-buyuk-yazi');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scale == 1) await shot(tester, key, 'kesfet-paket');
    });
  }

  test('coupon arithmetic retains kurus and clamps excessive discounts', () {
    final coupon = CouponModel.fromJson({...offerJson, 'discountValue': 500});
    expect(coupon.calculateDiscount(69.9), 69.9);
    final percentage = CouponModel.fromJson({
      ...offerJson,
      'discountType': 'percentage',
      'discountValue': 30,
      'maxDiscountAmount': 100,
    });
    expect(percentage.calculateDiscount(199.9), 59.97);
    expect(percentage.calculateDiscount(1000), 100);
  });

  for (final scale in [1.0, 2.0]) {
    visualTest('wallet remains usable at text scale $scale', (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: CouponsPage(package: package),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CouponTile), findsOneWidget);
      expect(tester.takeException(), isNull);
      await shot(
        tester,
        key,
        scale == 1 ? 'kuponlarim' : 'kuponlarim-buyuk-yazi',
      );
      await tester.scrollUntilVisible(find.text('Bu kuponu seç'), 160);
      expect(tester.takeException(), isNull);
    });
  }

  visualTest(
    'coupon selection returns the chosen offer without modifying the order',
    (tester) async {
      CouponModel? selected;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await openCoupons(context, package: package);
                },
                child: const Text('Kupon seç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Kupon seç'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Bu kuponu seç'), 160);
      await tester.tap(find.text('Bu kuponu seç'));
      await tester.pumpAndSettle();
      expect(selected?.code, 'ILK100');
      expect(adapter.calls.where((r) => r.path == '/orders'), isEmpty);
    },
  );

  visualTest(
    'unavailable and empty campaigns never show a redeem action or banner',
    (tester) async {
      adapter.unavailable = true;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: CouponsPage(package: package),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bu kuponu seç'), findsNothing);
      expect(find.text('İlk sipariş hakkınız kullanıldı'), findsOneWidget);
      adapter.empty = true;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: CampaignBanner(latitude: 41, longitude: 29)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('indirim'), findsNothing);
    },
  );

  visualTest(
    'checkout uses the server quote and displays the exact final amount',
    (tester) async {
      final bloc = ReservationBloc(
        repository: BusinessesRepositoryImpl(
          remoteDataSource: BusinessesRemoteDataSource(dioClient: appDioClient),
        ),
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: ReservationConfirmSheet(
                package: package,
                initialCoupon: CouponModel.fromJson(offerJson),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bloc.state, isA<CouponValidated>());
      expect((bloc.state as CouponValidated).discount, 100);
      final quote = adapter.calls.firstWhere(
        (r) => r.path == '/coupons/validate',
      );
      expect(quote.data['packageId'], package.id);
      expect(find.textContaining('499,90'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  visualTest(
    'quantity controls respect stock and revalidate the 500 TL coupon subtotal',
    (tester) async {
      adapter.unitPrice = 250;
      final twoPack = PackageModel.fromJson({
        ...packageJson,
        'discountedPrice': 250,
        'remainingQuantity': 3,
      });
      final bloc = ReservationBloc(
        repository: BusinessesRepositoryImpl(
          remoteDataSource: BusinessesRemoteDataSource(dioClient: appDioClient),
        ),
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: ReservationConfirmSheet(
                package: twoPack,
                initialQuantity: 2,
                initialCoupon: CouponModel.fromJson(offerJson),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('400,00'), findsWidgets);
      expect(
        adapter.calls
            .lastWhere((r) => r.path == '/coupons/validate')
            .data['quantity'],
        2,
      );
      await tester.tap(find.byTooltip('Adedi artır'));
      await tester.pumpAndSettle();
      expect(find.textContaining('650,00'), findsWidgets);
      expect(
        adapter.calls
            .lastWhere((r) => r.path == '/coupons/validate')
            .data['quantity'],
        3,
      );
      final plus = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Adedi artır',
        ),
      );
      expect(plus.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
