import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../config/theme.dart';
import '../../../home/data/models/business_model.dart';

/// Shared, size-bounded marker raster cache across map tab visits.
class MapMarkerIcons {
  static const int _tealColor = 0xFF0E5A4F;
  static const double _ikonCizimBoyutu = 120;
  static const int _iconSize = 192;
  static const int _capacity = 200;
  static final Map<String, Uint8List> _cache = {};
  static Uint8List? _locationIcon;

  String _key(BusinessModel business, {bool placeholder = false}) {
    final letter = business.name.isEmpty ? '?' : business.name[0].toUpperCase();
    final logo = placeholder ? '' : (business.imageUrl ?? '');
    final count = business.packageCount.clamp(0, 100);
    return '$logo|$letter|$count';
  }

  Uint8List? cached(BusinessModel business) => _get(_key(business));

  Uint8List? _get(String key) {
    final bytes = _cache.remove(key);
    if (bytes != null) _cache[key] = bytes;
    return bytes;
  }

  void _put(String key, Uint8List bytes) {
    _cache.remove(key);
    if (_cache.length >= _capacity) _cache.remove(_cache.keys.first);
    _cache[key] = bytes;
  }

  Future<Uint8List> placeholder(BusinessModel business) async {
    final key = _key(business, placeholder: true);
    final existing = _get(key);
    if (existing != null) return existing;
    final bytes = await _createLogoMarkerIcon(business, null);
    _put(key, bytes);
    return bytes;
  }

  /// Failed downloads leave the usable initial marker and can retry next visit.
  Future<Uint8List?> logo(BusinessModel business) async {
    final existing = cached(business);
    if (existing != null) return existing;
    final image = await _loadNetworkImage(business.imageUrl);
    if (image == null) return null;
    try {
      final bytes = await _createLogoMarkerIcon(business, image);
      _put(_key(business), bytes);
      return bytes;
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List> currentLocation() async =>
      _locationIcon ??= await _createCurrentLocationIcon();

  Future<Uint8List> _createLogoMarkerIcon(
    BusinessModel business,
    ui.Image? logo,
  ) async {
    const double size = _ikonCizimBoyutu;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, _iconSize.toDouble(), _iconSize.toDouble()),
    );
    // Çizim 120 birim üzerinden yapılır, raster daha büyük: ölçekle.
    canvas.scale(_iconSize / size);

    const center = Offset(size / 2, size / 2);
    const radius = 44.0;

    // Gölge.
    canvas.drawCircle(
      center.translate(0, 3),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Beyaz daire taban.
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    if (logo != null) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius - 3)),
      );
      final src = _coverSrcRect(logo);
      canvas.drawImageRect(
        logo,
        src,
        Rect.fromCircle(center: center, radius: radius - 3),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(center, radius - 3, Paint()..color = AppColors.primary);
      final letter = business.name.isNotEmpty ? business.name[0] : '?';
      final tp = TextPainter(
        text: TextSpan(
          text: letter.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            fontFamily: 'Korolev',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
      tp.dispose();
    }

    // Beyaz kenarlık halkası.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Paket-sayısı rozeti (sağ üst).
    if (business.packageCount > 0) {
      const badgeCenter = Offset(size - 30, 30);
      const badgeRadius = 22.0;
      canvas.drawCircle(
        badgeCenter,
        badgeRadius + 2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        badgeCenter,
        badgeRadius,
        Paint()..color = const Color(_tealColor),
      );
      final countText = business.packageCount > 99
          ? '99+'
          : '${business.packageCount}';
      final tp = TextPainter(
        text: TextSpan(
          text: countText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, badgeCenter.translate(-tp.width / 2, -tp.height / 2));
      tp.dispose();
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(_iconSize, _iconSize);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// Logoyu kareye "cover" şeklinde sığdırmak için kaynak dikdörtgeni hesaplar.
  Rect _coverSrcRect(ui.Image image) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final side = w < h ? w : h;
    final dx = (w - side) / 2;
    final dy = (h - side) / 2;
    return Rect.fromLTWH(dx, dy, side, side);
  }

  Future<ui.Image?> _loadNetworkImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    ImageStream? stream;
    ImageStreamListener? listener;
    try {
      final completer = Completer<ui.Image?>();
      // CachedNetworkImageProvider, uygulamanın geri kalanıyla (app_cached_image)
      // aynı DISK önbelleğini kullanır. Düz NetworkImage yalnız bellekte tutuyordu,
      // yani logolar uygulama her açılışında yeniden indiriliyordu.
      stream = ResizeImage(
        // Decode at the target size. Disk-cache resizing first decodes the
        // full original, which can briefly allocate tens of MB for one logo.
        CachedNetworkImageProvider(url),
        width: _iconSize,
        height: _iconSize,
        policy: ResizeImagePolicy.fit,
      ).resolve(const ImageConfiguration());
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image.clone());
          info.dispose();
        },
        onError: (e, st) {
          if (!completer.isCompleted) completer.complete(null);
        },
      );
      stream.addListener(listener);
      return await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    } finally {
      if (stream != null && listener != null) stream.removeListener(listener);
    }
  }

  Future<Uint8List> _createCurrentLocationIcon() async {
    const size = 200.0;
    const rasterBoyutu = 300.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, rasterBoyutu, rasterBoyutu),
    );
    canvas.scale(rasterBoyutu / size);
    const center = Offset(size / 2, size / 2);

    final pulsePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A90D9).withValues(alpha: 0.25),
          const Color(0xFF4A90D9).withValues(alpha: 0.0),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size / 2));
    canvas.drawCircle(center, size / 2, pulsePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, size / 4.5, borderPaint);

    final innerPaint = Paint()..color = const Color(0xFF4A90D9);
    canvas.drawCircle(center, size / 4.5, innerPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, size / 14, dotPaint);

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        rasterBoyutu.toInt(),
        rasterBoyutu.toInt(),
      );
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
