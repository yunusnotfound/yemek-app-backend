import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/category_model.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/category_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'campaign_ui_test.dart' as preview;

const categories = [
  CategoryModel(id: 0, name: 'Hepsi', slug: 'all'),
  CategoryModel(id: 1, name: 'Restoran', slug: 'restoran'),
  CategoryModel(id: 2, name: 'Fırın', slug: 'firin'),
  CategoryModel(id: 3, name: 'Pastane', slug: 'pastane'),
  CategoryModel(id: 4, name: 'Market', slug: 'market'),
  CategoryModel(id: 5, name: 'Kafe', slug: 'kafe'),
  CategoryModel(id: 6, name: 'Manav', slug: 'manav'),
  CategoryModel(id: 7, name: 'Kasap', slug: 'kasap'),
  CategoryModel(id: 8, name: 'Büfe', slug: 'bufe'),
];

Future<GlobalKey> mount(
  WidgetTester tester, {
  List<CategoryModel> items = categories,
  double width = 390,
  double scale = 1,
  ValueChanged<int>? onSelected,
}) async {
  tester.view.physicalSize = Size(width, 260);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey();
  var selected = 0;
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale), devicePixelRatio: 3),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: CategoryTiles(
                categories: items,
                selectedIndex: selected,
                onCategorySelected: (index) {
                  setState(() => selected = index);
                  onSelected?.call(index);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Future<void> decodeVisiblePhotos(WidgetTester tester) async {
  final context = tester.element(find.byType(CategoryTiles));
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  await tester.runAsync(() async {
    await Future.wait(
      images.map((image) => precacheImage(image.image, context)),
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Korolev');
    for (final weight in ['Medium', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Korolev $weight.otf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  preview.visualTest('All eight API categories decode their own photograph', (
    tester,
  ) async {
    final key = await mount(tester, width: 960);
    await decodeVisiblePhotos(tester);
    final rendered = tester.widgetList<RawImage>(find.byType(RawImage));
    expect(rendered, hasLength(8));
    expect(rendered.every((image) => image.image != null), isTrue);
    // 84 logical pixels at 3x use bounded thumbnails instead of full originals.
    expect(rendered.every((image) => image.image!.width <= 252), isTrue);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    await preview.shot(tester, key, 'kategoriler-tumu');
  });

  for (final scale in [1.0, 2.4]) {
    preview.visualTest(
      'Category selection survives scrolling at scale $scale',
      (tester) async {
        final selectedIds = <int>[];
        final key = await mount(
          tester,
          width: 320,
          scale: scale,
          onSelected: (index) => selectedIds.add(categories[index].id),
        );
        await decodeVisiblePhotos(tester);
        await preview.shot(tester, key, 'kategoriler-baslangic-$scale');
        for (final category in categories.skip(1)) {
          await tester.scrollUntilVisible(
            find.text(category.name),
            80,
            scrollable: find.byType(Scrollable),
          );
          await tester.tap(find.text(category.name));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(selectedIds, orderedEquals([1, 2, 3, 4, 5, 6, 7, 8]));
        final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
        expect(
          semantics.any(
            (s) =>
                s.properties.label == 'Büfe' && s.properties.selected == true,
          ),
          isTrue,
        );
        await decodeVisiblePhotos(tester);
        await preview.shot(tester, key, 'kategoriler-son-$scale');
      },
    );
  }

  testWidgets(
    'Legacy bakery keeps a photo and unknown categories stay usable',
    (tester) async {
      var selected = -1;
      await mount(
        tester,
        items: const [
          CategoryModel(id: 12, name: 'Fırın & Pastane', slug: 'firin-pastane'),
          CategoryModel(id: 91, name: 'Yeni kategori', slug: 'yeni-kategori'),
        ],
        onSelected: (index) => selected = index,
      );
      await decodeVisiblePhotos(tester);
      expect(find.byType(RawImage), findsOneWidget);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
      await tester.tap(find.text('Yeni kategori'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
