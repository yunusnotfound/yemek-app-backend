import 'dart:ui' as ui;

import 'package:bitir_yemek_mobile/shared/widgets/app_cached_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingImage extends ImageStreamCompleter {
  void complete(ui.Image image) => setImage(ImageInfo(image: image));
}

// Control the image stream at Flutter's cache boundary without network, disk,
// platform plugins, or a testing-only parameter in the production widget.
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
}

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => _ImageCache();
}

Widget _subject(String url, {double? width}) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 3),
    child: Center(
      child: SizedBox(
        width: 200,
        height: 120,
        child: AppCachedImage(
          imageUrl: url,
          width: width,
          placeholder: const Text('fallback'),
          loadingWidget: const Text('loading'),
        ),
      ),
    ),
  ),
);

void main() {
  final binding = _Binding();
  final cache = binding.imageCache as _ImageCache;
  setUp(cache.requests.clear);

  testWidgets('production photos download a density-aware CDN variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject('https://api.bitirgitsin.com/uploads/meal.png'),
    );
    final expectedKey = await ResizeImage(
      const CachedNetworkImageProvider(
        'https://api.bitirgitsin.com/cdn-cgi/image/width=640,'
        'fit=scale-down,format=webp,quality=85,onerror=redirect/uploads/meal.png',
      ),
      width: 600,
    ).obtainKey(ImageConfiguration.empty);
    expect(cache.requests.keys, [expectedKey]);
    final resized =
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    final provider = resized.imageProvider as CachedNetworkImageProvider;
    expect(provider.headers, {
      'Accept': 'image/webp,image/jpeg,image/png;q=0.8',
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'visible image uses parent bounds and never decodes the original',
    (tester) async {
      const url = 'https://images.example.test/meal.webp';
      await tester.pumpWidget(_subject(url));
      final expectedKey = await ResizeImage(
        const CachedNetworkImageProvider(url),
        width: 600,
      ).obtainKey(ImageConfiguration.empty);
      expect(cache.requests.keys, [expectedKey]);
      final resized =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      final provider = resized.imageProvider as CachedNetworkImageProvider;
      expect(provider.headers, isNull);
      final image = await tester.runAsync(createTestImage);
      cache.requests.values.single.complete(image!);
      await tester.pump();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.text('loading'), findsNothing);
      expect(cache.requests.keys, [expectedKey]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a slow image can appear after the loading timeout', (
    tester,
  ) async {
    await tester.pumpWidget(_subject('https://images.example.test/slow.webp'));
    expect(find.text('loading'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('fallback'), findsOneWidget);
    expect(cache.requests.values.single.hasListeners, isTrue);
    final image = await tester.runAsync(createTestImage);
    cache.requests.values.single.complete(image!);
    await tester.pump();
    expect(find.text('fallback'), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an infinite width is safe and a new URL gets a fresh timeout', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject('https://images.example.test/old.webp', width: double.infinity),
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('fallback'), findsOneWidget);
    await tester.pumpWidget(
      _subject('https://images.example.test/new.webp', width: double.infinity),
    );
    expect(find.text('loading'), findsOneWidget);
    expect(cache.requests, hasLength(2));
    expect(cache.requests.values.first.hasListeners, isFalse);
    expect(cache.requests.values.last.hasListeners, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
