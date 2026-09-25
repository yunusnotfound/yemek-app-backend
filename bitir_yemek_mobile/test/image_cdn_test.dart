import 'package:bitir_yemek_mobile/core/utils/image_cdn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = 'https://api.bitirgitsin.com/uploads/demo-catalog-v1/kafe.png';

  test('physical widths select only four capped reusable variants', () {
    for (final (requested, width) in [
      (1.0, 320),
      (320.0, 320),
      (320.1, 640),
      (640.0, 640),
      (640.1, 960),
      (960.0, 960),
      (960.1, 1280),
      (1280.0, 1280),
      (10000.0, 1280),
    ]) {
      expect(
        imageCdnUrl(source, pixelWidth: requested),
        'https://api.bitirgitsin.com/cdn-cgi/image/width=$width,'
        'fit=scale-down,format=webp,quality=85,onerror=redirect'
        '/uploads/demo-catalog-v1/kafe.png',
      );
    }
    expect({
      for (var width = 1; width <= 4096; width++)
        imageCdnUrl(source, pixelWidth: width.toDouble()),
    }, hasLength(4));
  });

  test('missing or invalid dimensions use a 960 pixel image', () {
    for (final width in [null, 0.0, -1.0, double.infinity, double.nan]) {
      expect(imageCdnUrl(source, pixelWidth: width), contains('/width=960,'));
    }
  });

  test(
    'only versioned app artwork explicitly preserves transparent cutouts',
    () {
      const artwork =
          'https://api.bitirgitsin.com/uploads/app-artwork-v1/'
          'onboarding/foodbox-meal.webp';
      expect(imageCdnUrl(artwork), contains('background=transparent,'));
      expect(imageCdnUrl(source), isNot(contains('background=')));
      expect(
        imageCdnUrl(
          artwork.replaceFirst('app-artwork-v1/', 'app-artwork-v10/'),
        ),
        isNot(contains('background=')),
      );
    },
  );

  test('signed, authenticated and non-production requests are unchanged', () {
    for (final url in [
      'https://api.bitirgitsin.com/uploads/kafe.png?token=private%2Bsignature',
      'https://api.bitirgitsin.com/uploads/kafe.png?',
      'https://api.bitirgitsin.com/uploads/kafe.png#fragment',
      'https://user:password@api.bitirgitsin.com/uploads/kafe.png',
      'http://api.bitirgitsin.com/uploads/kafe.png',
      'https://api.bitirgitsin.com:8443/uploads/kafe.png',
      'https://api.bitirgitsin.com.evil.test/uploads/kafe.png',
      'https://staging.bitirgitsin.com/uploads/kafe.png',
      'http://localhost:3000/uploads/kafe.png',
      'https://thirdparty.example/uploads/kafe.png',
      'https://api.bitirgitsin.com/api/private/kafe.png',
      'https://api.bitirgitsin.com/uploads-private/kafe.png',
      'https://api.bitirgitsin.com/uploads',
      'https://api.bitirgitsin.com/uploads/',
      '/uploads/kafe.png',
      'data:image/png;base64,AAAA',
      'https://[invalid',
      '',
    ]) {
      expect(imageCdnUrl(url, pixelWidth: 320), url);
    }
  });

  test(
    'escaped filenames survive and transformed URLs are not wrapped again',
    () {
      const url =
          'https://api.bitirgitsin.com/uploads/%C3%B6%C4%9F%C3%BCn%20kutusu.png';
      final transformed = imageCdnUrl(url);
      expect(
        transformed,
        endsWith('/uploads/%C3%B6%C4%9F%C3%BCn%20kutusu.png'),
      );
      expect(imageCdnUrl(transformed, pixelWidth: 320), transformed);
    },
  );
}
