import 'dart:ui' as ui;

import 'package:bitir_yemek_mobile/core/utils/app_artwork.dart';
import 'package:bitir_yemek_mobile/core/utils/cached_image_provider.dart';
import 'package:bitir_yemek_mobile/features/auth/presentation/widgets/hinged_package.dart';
import 'package:bitir_yemek_mobile/shared/widgets/app_artwork_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _bakery = 'assets/images/onboarding/foodbox-bakery.webp';
const _meal = 'assets/images/onboarding/foodbox-meal.webp';
const _kraft = 'assets/images/onboarding/kraft-texture.webp';

class _PendingImage extends ImageStreamCompleter {
  late final _handle = keepAlive();

  _PendingImage() {
    _handle;
  }

  void complete(ui.Image image) => setImage(ImageInfo(image: image));
  void fail() => reportError(exception: Exception('offline'));
  void dispose() => _handle.dispose();
}

class _ImageCache extends ImageCache {
  final requests = <Object, _PendingImage>{};

  @override
  ImageStreamCompleter? putIfAbsent(
    Object key,
    ImageStreamCompleter Function() loader, {
    ImageErrorListener? onError,
  }) {
    if (key is ResizeImageKey || key is CachedNetworkImageProvider) {
      return requests.putIfAbsent(key, _PendingImage.new);
    }
    return super.putIfAbsent(key, loader, onError: onError);
  }

  void reset() {
    for (final request in requests.values) {
      request.dispose();
    }
    requests.clear();
  }
}

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => _ImageCache();
}

Widget _subject(String asset, {bool canvas = false}) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 3),
    child: Center(
      child: canvas
          ? HingedPackage(opening: 1, foodAsset: asset)
          : AppArtworkImage(asset, width: 200, height: 200),
    ),
  ),
);

Future<_PendingImage> _request(
  WidgetTester tester,
  String asset, {
  bool remote = false,
  bool canvas = false,
}) async {
  final source = resolveAppArtwork(asset);
  final provider = remote
      ? cachedImageProvider(
          source.imageUrl!,
          pixelWidth: canvas ? 512 : 600,
          cacheWidth: canvas ? 512 : 600,
        )
      : ResizeImage(AssetImage(source.localAsset), width: 128);
  final context = tester.element(
    find.byType(canvas ? HingedPackage : AppArtworkImage),
  );
  final key = await provider.obtainKey(createLocalImageConfiguration(context));
  return (tester.binding.imageCache as _ImageCache).requests[key]!;
}

dynamic _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(HingedPackage),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter;

Future<void> _complete(
  WidgetTester tester,
  _PendingImage request,
  int width,
) async {
  final image = await tester.runAsync(
    () => createTestImage(width: width, height: width),
  );
  request.complete(image!);
  await tester.pump();
}

void main() {
  final binding = _Binding();
  final cache = binding.imageCache as _ImageCache;
  tearDown(cache.reset);

  test(
    'all 14 CDN originals have bundled previews and are not in the app',
    () async {
      final bundled = (await AssetManifest.loadFromAssetBundle(
        rootBundle,
      )).listAssets();
      final assets = [
        for (final category in [
          'bufe',
          'firin',
          'kafe',
          'kasap',
          'manav',
          'market',
          'pastane',
          'restoran',
        ])
          'assets/images/categories/$category.webp',
        for (final artwork in [
          'foodbox-bakery',
          'foodbox-dessert',
          'foodbox-meal',
          'kraft-texture',
          'rescue-bag',
          'waste-bin',
        ])
          'assets/images/onboarding/$artwork.webp',
      ];
      expect(assets, hasLength(14));
      for (final asset in assets) {
        final source = resolveAppArtwork(asset);
        final relative = asset.substring('assets/images/'.length);
        expect(source.localAsset, 'assets/previews/$relative');
        expect(
          source.imageUrl,
          'https://api.bitirgitsin.com/uploads/app-artwork-v1/$relative',
        );
        expect(bundled, contains(source.localAsset));
        expect(bundled, isNot(contains(asset)));
      }
      for (final local in [
        'assets/images/food_box.png',
        'assets/images/google-mark.png',
        'assets/icon/app_icon.png',
        'assets/images/categories/unknown.webp',
        'assets/images/categories/../categories/kafe.webp',
        'assets/images/categories/kafe.webp?token=x',
        'https://example.test/kafe.webp',
      ]) {
        expect(resolveAppArtwork(local).localAsset, local);
        expect(resolveAppArtwork(local).imageUrl, isNull);
      }
      expect(
        bundled,
        containsAll([
          'assets/images/food_box.png',
          'assets/images/google-mark.png',
          'assets/icon/app_icon.png',
        ]),
      );
    },
  );

  testWidgets('offline artwork keeps its decoded preview without a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(_bakery));
    await _complete(tester, await _request(tester, _bakery), 128);
    final preview = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(preview.width, 128);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    (await _request(tester, _bakery, remote: true)).fail();
    await tester.pump();
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(preview),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a delayed CDN image upgrades the preview even after timeout', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(_bakery));
    await _complete(tester, await _request(tester, _bakery), 128);
    await tester.pump(const Duration(seconds: 20));
    expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 128);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final remote = await _request(tester, _bakery, remote: true);
    expect(remote.hasListeners, isTrue);
    await _complete(tester, remote, 600);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 600);
    final provider =
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    final network = provider.imageProvider as CachedNetworkImageProvider;
    expect(network.url, contains('width=640,'));
    expect(network.url, contains('background=transparent,'));
    expect(network.headers?['Accept'], 'image/webp,image/jpeg,image/png;q=0.8');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changing artwork never displays a stale remote response', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(_bakery));
    await _complete(tester, await _request(tester, _bakery), 128);
    final oldRemote = await _request(tester, _bakery, remote: true);
    await tester.pumpWidget(_subject(_meal));
    await _complete(tester, await _request(tester, _meal), 120);
    expect(oldRemote.hasListeners, isFalse);
    await _complete(tester, oldRemote, 600);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 120);
    await tester.pumpWidget(const SizedBox());
    expect(
      cache.requests.values.every((request) => !request.hasListeners),
      isTrue,
    );
  });

  testWidgets(
    'canvas previews survive offline errors and upgrade independently',
    (tester) async {
      await tester.pumpWidget(_subject(_bakery, canvas: true));
      await _complete(
        tester,
        await _request(tester, _bakery, canvas: true),
        128,
      );
      await _complete(
        tester,
        await _request(tester, _kraft, canvas: true),
        128,
      );
      final ui.Image foodPreview = _painter(tester).food;
      final ui.Image kraftPreview = _painter(tester).cardboard;
      (await _request(tester, _kraft, canvas: true, remote: true)).fail();
      await tester.pump(const Duration(seconds: 20));
      expect(_painter(tester).food, foodPreview);
      expect(_painter(tester).cardboard, kraftPreview);
      await _complete(
        tester,
        await _request(tester, _bakery, canvas: true, remote: true),
        512,
      );
      expect((_painter(tester).food as ui.Image).width, 512);
      expect(foodPreview.debugDisposed, isTrue);
      expect(kraftPreview.debugDisposed, isFalse);
      expect(tester.takeException(), isNull);
      final ui.Image remoteFood = _painter(tester).food;
      await tester.pumpWidget(const SizedBox());
      expect(remoteFood.debugDisposed, isTrue);
      expect(kraftPreview.debugDisposed, isTrue);
      expect(
        cache.requests.values.every((request) => !request.hasListeners),
        isTrue,
      );
      // Reopening resolves synchronously from the same cache, with new owned
      // handles instead of the image handles disposed by the previous canvas.
      await tester.pumpWidget(_subject(_bakery, canvas: true));
      expect((_painter(tester).food as ui.Image).width, 512);
      expect((_painter(tester).cardboard as ui.Image).width, 128);
      expect((_painter(tester).food as ui.Image).debugDisposed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'canvas rejects late old food, late previews and disposed updates',
    (tester) async {
      await tester.pumpWidget(_subject(_bakery, canvas: true));
      final oldPreview = await _request(tester, _bakery, canvas: true);
      final oldRemote = await _request(
        tester,
        _bakery,
        canvas: true,
        remote: true,
      );
      await tester.pumpWidget(_subject(_meal, canvas: true));
      final mealPreview = await _request(tester, _meal, canvas: true);
      final mealRemote = await _request(
        tester,
        _meal,
        canvas: true,
        remote: true,
      );
      await _complete(tester, mealRemote, 512);
      final ui.Image food = _painter(tester).food;
      await _complete(tester, mealPreview, 128);
      await _complete(tester, oldPreview, 100);
      await _complete(tester, oldRemote, 500);
      expect(_painter(tester).food, food);
      expect(oldPreview.hasListeners, isFalse);
      expect(oldRemote.hasListeners, isFalse);
      final kraftRemote = await _request(
        tester,
        _kraft,
        canvas: true,
        remote: true,
      );
      await tester.pumpWidget(const SizedBox());
      await _complete(tester, kraftRemote, 512);
      expect(food.debugDisposed, isTrue);
      expect(
        cache.requests.values.every((request) => !request.hasListeners),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
