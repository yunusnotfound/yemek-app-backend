import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/core/di/service_locator.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/package_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/repositories/businesses_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/packages_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/pages/home_page.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/home_catalog_cards.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/widgets/favorite_button.dart';
import 'campaign_ui_test.dart' as preview;
import 'state_consistency_test.dart' as fixtures;

PackageModel product(int number) => PackageModel.fromJson({
  ...preview.packageJson,
  'id': 'product-$number',
  'title': 'Ürün $number',
});

class FeedRepository extends fixtures.CatalogFake {
  bool failSecondPage = false;

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
    pages.add(page);
    if (page == 2 && failSecondPage) return PackagesResult.failure('offline');
    return PackagesResult.success(
      packages: List.generate(
        page == 1 ? 10 : 4,
        (i) => product((page - 1) * 10 + i + 1),
      ),
      pagination: PaginationModel(
        total: 14,
        page: page,
        limit: 10,
        totalPages: 2,
      ),
    );
  }
}

void main() {
  testWidgets(
    'home groups businesses, scrolls through products and preserves loaded pages on refresh',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appDioClient.dio.interceptors.clear();
      appDioClient.dio.httpClientAdapter = preview.CampaignAdapter()
        ..empty = true;
      final repository = FeedRepository();
      final packages = PackagesBloc(repository: repository);
      final home = preview.PreviewHome();
      final favorites = FavoritesBloc(repository: fixtures.FavoritesFake());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<PackagesBloc>.value(value: packages),
              BlocProvider<HomeBloc>.value(value: home),
              BlocProvider<FavoritesBloc>.value(value: favorites),
            ],
            child: const HomeView(latitude: 41, longitude: 29),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Ten products from one business should produce exactly one business card.
      expect(find.byType(HomeBusinessCard), findsOneWidget);
      expect(find.text('Keşfetmeye devam et'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('home-catalog')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Ürün 14'),
        350,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(repository.pages, [1, 2]);
      final position = tester.state<ScrollableState>(scrollable).position;
      final offset = position.pixels;
      packages.refreshCurrent();
      await tester.pumpAndSettle();
      expect(repository.pages, [1, 2, 1, 2]);
      expect((packages.state as PackagesLoaded).packages, hasLength(14));
      expect(position.pixels, offset);
      expect(find.text('Ürün 14'), findsOneWidget);
      repository.failSecondPage = true;
      packages.refreshCurrent();
      await tester.pumpAndSettle();
      expect((packages.state as PackagesLoaded).packages, hasLength(14));
      expect(position.pixels, offset);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await packages.close();
        await home.close();
        await favorites.close();
      });
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'business and product cards fit a narrow screen at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final favoriteRepository = fixtures.FavoritesFake()..adding.complete();
        final favorites = FavoritesBloc(repository: favoriteRepository);
        var businessTaps = 0;
        var productTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: BlocProvider.value(
              value: favorites,
              child: Scaffold(
                body: Builder(
                  builder: (context) => SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          height: HomeBusinessCard.carouselHeight(context),
                          child: HomeBusinessCard(
                            business: product(1).business,
                            onTap: () => businessTaps++,
                          ),
                        ),
                        const SizedBox(height: 20),
                        HomeProductCard(
                          package: product(1),
                          onTap: () => productTaps++,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paketleri keşfet'));
        await tester.ensureVisible(find.text('Ürün 1'));
        await tester.tap(find.text('Ürün 1'));
        expect(businessTaps, 1);
        expect(productTaps, 1);
        final favoriteButton = find.descendant(
          of: find.byType(HomeProductCard),
          matching: find.byType(FavoriteButton),
        );
        await tester.ensureVisible(favoriteButton);
        await tester.tap(favoriteButton);
        await tester.pumpAndSettle();
        expect(favorites.isFavorite(product(1).business.id), isTrue);
        expect(productTaps, 1);
        await tester.tap(favoriteButton);
        await tester.pumpAndSettle();
        expect(favorites.isFavorite(product(1).business.id), isFalse);
        expect(productTaps, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(favorites.close);
      },
    );
  }
}
