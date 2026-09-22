import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Photographed takeaway tray with a rounded lid rotating around its rear hinge.
/// Food is rendered at its natural proportions, never flattened onto a plane.
class HingedPackage extends StatefulWidget {
  final double opening;
  final String foodAsset;

  const HingedPackage({
    super.key,
    required this.opening,
    required this.foodAsset,
  });

  @override
  State<HingedPackage> createState() => _HingedPackageState();
}

class _HingedPackageState extends State<HingedPackage> {
  ui.Image? _cardboard;
  ui.Image? _food;
  int _foodRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadCardboard();
    _loadFood();
  }

  Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      targetWidth: 512,
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _loadCardboard() async {
    try {
      final image = await _decode('assets/images/onboarding/kraft-texture.png');
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _cardboard = image);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    }
  }

  Future<void> _loadFood() async {
    final request = ++_foodRequest;
    try {
      final image = await _decode(widget.foodAsset);
      if (!mounted || request != _foodRequest) {
        image.dispose();
        return;
      }
      final previous = _food;
      setState(() => _food = image);
      previous?.dispose();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    }
  }

  @override
  void didUpdateWidget(HingedPackage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foodAsset != widget.foodAsset) _loadFood();
  }

  @override
  void dispose() {
    _cardboard?.dispose();
    _food?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(300, 340),
    painter: _PackagePainter(
      opening: widget.opening,
      cardboard: _cardboard,
      food: _food,
    ),
  );
}

class _PackagePainter extends CustomPainter {
  final double opening;
  final ui.Image? cardboard;
  final ui.Image? food;

  _PackagePainter({required this.opening, this.cardboard, this.food});

  static const _hingeY = 150.0;
  static const _lidWidth = 228.0;
  static const _lidLength = 136.0;
  static const _trayRect = Rect.fromLTWH(35, 114, 230, 230);
  static final _identity = Float64List.fromList([
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  /// Project each point of the rounded lid around the same rear hinge.
  Offset _project(Offset point) {
    final angle = opening * math.pi * 0.49;
    return Offset(
      150 + point.dx,
      _hingeY + point.dy * (math.cos(angle) - math.sin(angle)),
    );
  }

  List<Offset> _outline(Rect rect, double radius) {
    final points = <Offset>[];
    final centers = [
      Offset(rect.left + radius, rect.top + radius),
      Offset(rect.right - radius, rect.top + radius),
      Offset(rect.right - radius, rect.bottom - radius),
      Offset(rect.left + radius, rect.bottom - radius),
    ];
    for (var corner = 0; corner < 4; corner++) {
      for (var step = 0; step <= 8; step++) {
        final angle = math.pi + corner * math.pi / 2 + step * math.pi / 16;
        points.add(
          centers[corner] + Offset(math.cos(angle), math.sin(angle)) * radius,
        );
      }
    }
    return points;
  }

  void _paintLid(Canvas canvas) {
    const bounds = Rect.fromLTWH(-_lidWidth / 2, 0, _lidWidth, _lidLength);
    final outline = _outline(bounds, 26);
    final projected = outline.map(_project).toList();
    final lidPath = Path()..addPolygon(projected, true);

    // A thick rolled lip, rounded corners and an inset panel match a food tray.
    canvas.drawPath(
      lidPath.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0xFF96764E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    if (cardboard case final texture?) {
      final vertices = ui.Vertices(
        ui.VertexMode.triangleFan,
        [_project(bounds.center), ...projected, projected.first],
        textureCoordinates: [bounds.center, ...outline, outline.first]
            .map(
              (p) => Offset(
                (p.dx - bounds.left) / bounds.width * texture.width,
                p.dy / bounds.height * texture.height,
              ),
            )
            .toList(),
      );
      final shader = ImageShader(
        texture,
        TileMode.clamp,
        TileMode.clamp,
        _identity,
      );
      canvas.drawVertices(
        vertices,
        BlendMode.srcOver,
        Paint()
          ..shader = shader
          ..filterQuality = FilterQuality.medium,
      );
      vertices.dispose();
      shader.dispose();
    } else {
      canvas.drawPath(lidPath, Paint()..color = const Color(0xFFCAA67C));
    }
    canvas.drawPath(
      lidPath,
      Paint()
        ..color = const Color(0xFFE5C79C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final inset = Path()
      ..addPolygon(
        _outline(bounds.deflate(9), 19).map(_project).toList(),
        true,
      );
    canvas.drawPath(
      inset,
      Paint()
        ..color = const Color(0xFF8E6D45).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawPath(
      inset.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0xFFF4DDB7).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Rounded front closing tab rotates with the lid as one physical part.
    final tab = _outline(const Rect.fromLTWH(-22, 129, 44, 15), 6);
    canvas.drawPath(
      Path()..addPolygon(tab.map(_project).toList(), true),
      Paint()..color = const Color(0xFFCAAC82),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 340);
    if (food case final image?) {
      canvas.save();
      // The raised food becomes visible as the lid clears the rear rim.
      // The actual photograph keeps its aspect ratio and natural food volume.
      final reveal = (opening / 0.4).clamp(0.0, 1.0);
      canvas.clipRect(Rect.fromLTRB(0, _hingeY - reveal * 100, 300, 340));
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        _trayRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }
    _paintLid(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PackagePainter oldDelegate) =>
      oldDelegate.opening != opening ||
      oldDelegate.cardboard != cardboard ||
      oldDelegate.food != food;
}
