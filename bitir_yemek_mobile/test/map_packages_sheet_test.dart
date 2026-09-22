import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/home_catalog_cards.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/widgets/map_packages_sheet.dart';
import 'home_catalog_test.dart' as catalog;
import 'state_consistency_test.dart' as fixtures;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'package panel opens, pins its header and collapses at scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final favorites = FavoritesBloc(repository: fixtures.FavoritesFake());
        var selected = '';
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
                body: MapPackagesSheet(
                  packages: List.generate(8, (i) => catalog.product(i + 1)),
                  count: 8,
                  onPackageTap: (package) => selected = package.id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sheet = tester.widget<DraggableScrollableSheet>(
          find.byType(DraggableScrollableSheet),
        );
        expect(sheet.controller!.size, closeTo(sheet.minChildSize, 0.001));
        await tester.tap(find.text('Yakınındaki paketler'));
        await tester.pumpAndSettle();
        expect(sheet.controller!.size, closeTo(0.58, 0.001));
        await tester.scrollUntilVisible(find.text('Ürün 1'), 100);
        await tester.tap(find.text('Ürün 1'));
        expect(selected, 'product-1');
        await tester.drag(
          find.byType(HomeProductCard).first,
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();
        expect(find.text('Yakınındaki paketler').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Yakınındaki paketler'));
        await tester.pumpAndSettle();
        expect(sheet.controller!.size, closeTo(sheet.minChildSize, 0.001));
        await tester.drag(
          find.text('Yakınındaki paketler'),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(sheet.controller!.size, greaterThan(sheet.minChildSize));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(favorites.close);
      },
    );
  }

  testWidgets('empty filtered panel shows an empty state instead of loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MapPackagesSheet(
            packages: const [],
            count: 0,
            onPackageTap: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Yakınındaki paketler'));
    await tester.pumpAndSettle();
    expect(find.text('0 sürpriz paket'), findsOneWidget);
    expect(find.text('Burada henüz paket yok'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
