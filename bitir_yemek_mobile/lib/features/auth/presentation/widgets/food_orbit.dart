import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import 'onboarding_photo.dart';

/// A gently moving collection of food photographs around a takeaway package.
class FoodOrbit extends StatefulWidget {
  const FoodOrbit({super.key});

  @override
  State<FoodOrbit> createState() => _FoodOrbitState();
}

class _FoodOrbitState extends State<FoodOrbit>
    with SingleTickerProviderStateMixin {
  static const _foods = [
    OnboardingAssets.bakery,
    OnboardingAssets.coffee,
    OnboardingAssets.dessert,
    OnboardingAssets.meal,
    OnboardingAssets.sandwich,
    OnboardingAssets.produce,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: AnimatedBuilder(
        animation: _controller,
        child: const OnboardingPhoto(
          asset: OnboardingAssets.openBox,
          size: 158,
          cutout: true,
        ),
        builder: (context, center) {
          final angle = _controller.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.sand.withValues(alpha: 0.35),
                      AppColors.sand.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < _foods.length; i++)
                Transform.translate(
                  offset: Offset(
                    math.cos(angle + i * math.pi / 3) * 114,
                    math.sin(angle + i * math.pi / 3) * 114,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.creamTop,
                      shape: BoxShape.circle,
                      boxShadow: AppDepth.card,
                    ),
                    child: OnboardingPhoto(asset: _foods[i], size: 62),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, math.sin(angle * 2) * 3),
                child: center,
              ),
            ],
          );
        },
      ),
    );
  }
}
