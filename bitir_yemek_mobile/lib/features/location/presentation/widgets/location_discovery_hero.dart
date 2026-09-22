import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// An illustrative neighborhood, not a preview of live businesses or distances.
class LocationDiscoveryHero extends StatelessWidget {
  const LocationDiscoveryHero({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.38,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: ColoredBox(
            color: const Color(0xFFF0E8DA),
            child: LayoutBuilder(
              builder: (context, constraints) => FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 360,
                  height: 360 / 1.38,
                  child: MediaQuery.withNoTextScaling(
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: _NeighborhoodPainter()),
                        ),
                        Positioned(
                          left: 18,
                          top: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.creamTop,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: AppDepth.card,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.successInk,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'LEZZET ÇOK YAKINDA',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 9,
                                    letterSpacing: 1.1,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          right: 12,
                          top: 28,
                          child: _FoodMarker(
                            asset: 'foodbox-meal.png',
                            label: 'Restoranlar',
                            angle: 0.10,
                          ),
                        ),
                        const Positioned(
                          left: 10,
                          bottom: 20,
                          child: _FoodMarker(
                            asset: 'foodbox-bakery.png',
                            label: 'Fırın & pastaneler',
                            angle: -0.12,
                          ),
                        ),
                        Positioned(
                          left: 157,
                          top: 113,
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(21),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40CB632E),
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.near_me_rounded,
                              color: Colors.white,
                              size: 29,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodMarker extends StatelessWidget {
  final String asset;
  final String label;
  final double angle;

  const _FoodMarker({
    required this.asset,
    required this.label,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 139,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: angle,
            child: Image.asset(
              'assets/images/onboarding/$asset',
              width: 132,
              height: 106,
              fit: BoxFit.contain,
              cacheWidth: 396,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.creamTop,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppDepth.card,
            ),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeighborhoodPainter extends CustomPainter {
  const _NeighborhoodPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 261);
    final paint = Paint();
    // Quiet city blocks and a green neighborhood park.
    for (final rect in const [
      Rect.fromLTWH(-20, 64, 98, 56),
      Rect.fromLTWH(104, -20, 65, 111),
      Rect.fromLTWH(196, -18, 76, 109),
      Rect.fromLTWH(300, 12, 74, 79),
      Rect.fromLTWH(102, 117, 67, 81),
      Rect.fromLTWH(193, 119, 93, 62),
      Rect.fromLTWH(309, 116, 70, 115),
      Rect.fromLTWH(133, 222, 85, 64),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        paint..color = const Color(0xFFE5DBC9),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(234, 206, 64, 78),
        const Radius.circular(18),
      ),
      paint..color = const Color(0xFFD2DDC3),
    );
    final street = Path()
      ..moveTo(-10, 140)
      ..cubicTo(83, 114, 179, 95, 374, 106)
      ..moveTo(183, -10)
      ..lineTo(182, 175)
      ..quadraticBezierTo(181, 199, 211, 214)
      ..lineTo(280, 271)
      ..moveTo(86, -10)
      ..lineTo(87, 184)
      ..quadraticBezierTo(89, 208, 124, 211)
      ..lineTo(365, 194);
    canvas.drawPath(
      street,
      Paint()
        ..color = const Color(0xFFFFFCF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    const center = Offset(186, 142);
    canvas.drawCircle(center, 65, paint..color = const Color(0x13FF7043));
    canvas.drawCircle(
      center,
      65,
      Paint()
        ..color = const Color(0x33DA8157)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(center, 43, paint..color = const Color(0x18FF7043));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NeighborhoodPainter oldDelegate) => false;
}
