import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// Onboarding ilk sayfasının görsel kompozisyonu.
///
/// Etkileşim YOKTUR — kullanıcıdan hiçbir şey beklenmez. Merkezdeki marka
/// yaprağının çevresinde iki halka hâlinde yiyecekler ters yönlerde, farklı
/// hızlarda, çok yavaş döner. Amaç ekranı "canlı" tutmak: hareket var ama
/// dikkat talep etmiyor, kullanıcı başlığı okurken arka planda akıyor.
///
/// Hiçbir veri/istek gerektirmez; tüm görsel çizimle üretilir.
class FoodOrbit extends StatefulWidget {
  const FoodOrbit({super.key});

  @override
  State<FoodOrbit> createState() => _FoodOrbitState();
}

class _FoodOrbitState extends State<FoodOrbit>
    with SingleTickerProviderStateMixin {
  // --- Sahne ölçüleri -------------------------------------------------------
  // En dıştaki öğe: yarıçap 120 + yarım boyut 16 = 136 < 140 (yarı genişlik).
  // Yani kompozisyon çerçeveye sığar, kırpılma olmaz.
  static const double _sahneBoyu = 280;
  static const double _icHalkaR = 84;
  static const double _disHalkaR = 120;
  static const double _icOgeBoyu = 46;
  static const double _disOgeBoyu = 32;

  /// Tek tur süresi. Bilerek çok uzun — dönüş fark edilir ama rahatsız etmez.
  static const Duration _turSuresi = Duration(seconds: 48);

  static const List<_Food> _icHalka = [
    _Food(Icons.bakery_dining_rounded, Color(0xFFD98E3E)),
    _Food(Icons.local_pizza_rounded, Color(0xFFE0663D)),
    _Food(Icons.ramen_dining_rounded, Color(0xFFC1443B)),
    _Food(Icons.local_cafe_rounded, Color(0xFF8D6E63)),
  ];

  static const List<_Food> _disHalka = [
    _Food(Icons.icecream_rounded, Color(0xFF00897B)),
    _Food(Icons.lunch_dining_rounded, Color(0xFF8D6E63)),
    _Food(Icons.egg_alt_rounded, Color(0xFFD98E3E)),
    _Food(Icons.set_meal_rounded, Color(0xFFC1443B)),
    // Halkadaki her öğe YİYECEK olmalı: burada önce bir çiçek ikonu vardı,
    // hem diziden kopuyordu hem de merkezdeki yaprakla yarışıp onu zayıflatıyordu.
    _Food(Icons.cookie_rounded, Color(0xFFB07A3E)),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _turSuresi)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _sahneBoyu,
      height: _sahneBoyu,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildGlow(t),
              _buildRingOutline(_disHalkaR),
              _buildRingOutline(_icHalkaR),
              // Dış halka ters yönde ve daha yavaş döner; iki halkanın birbirine
              // göre kayması kompozisyonu tekdüzelikten kurtarır.
              ..._buildOrbit(
                foods: _disHalka,
                radius: _disHalkaR,
                size: _disOgeBoyu,
                angle: -t * 2 * math.pi * 0.62,
                iconScale: 0.52,
                opacity: 0.72,
              ),
              ..._buildOrbit(
                foods: _icHalka,
                radius: _icHalkaR,
                size: _icOgeBoyu,
                angle: t * 2 * math.pi,
                iconScale: 0.56,
                opacity: 1,
              ),
              _buildCenter(t),
            ],
          );
        },
      ),
    );
  }

  /// Merkezden dışa açılan yumuşak yeşil hale; çok yavaş nefes alır.
  Widget _buildGlow(double t) {
    final nefes = 1 + math.sin(t * 2 * math.pi * 2) * 0.04;
    return Container(
      width: 200 * nefes,
      height: 200 * nefes,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF4CAF50).withValues(alpha: 0.13),
            const Color(0xFF4CAF50).withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  /// Halkaların ince iz çizgisi — öğelerin bir yörüngede olduğunu belli eder.
  Widget _buildRingOutline(double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.textHint.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
    );
  }

  /// Bir halkadaki öğeleri eşit açılarla yerleştirir.
  List<Widget> _buildOrbit({
    required List<_Food> foods,
    required double radius,
    required double size,
    required double angle,
    required double iconScale,
    required double opacity,
  }) {
    return List.generate(foods.length, (i) {
      final food = foods[i];
      final a = angle + (i * 2 * math.pi / foods.length);
      final dx = math.cos(a) * radius;
      final dy = math.sin(a) * radius;

      // Üst yarıdaki öğeler bir tık büyük görünsün: derinlik hissi verir.
      final derinlik = 1 + math.sin(a) * -0.06;

      return Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: derinlik,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: food.color.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                food.icon,
                size: size * iconScale,
                color: food.color,
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Ortadaki marka yaprağı.
  Widget _buildCenter(double t) {
    final nefes = 1 + math.sin(t * 2 * math.pi * 2) * 0.02;
    return Transform.scale(
      scale: nefes,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.22),
              blurRadius: 26,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.eco_rounded,
          size: 50,
          color: Color(0xFF4CAF50),
        ),
      ),
    );
  }
}

class _Food {
  final IconData icon;
  final Color color;
  const _Food(this.icon, this.color);
}
