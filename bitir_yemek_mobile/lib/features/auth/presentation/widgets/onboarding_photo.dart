import 'package:flutter/material.dart';

/// Local photography keeps the introduction available before sign-in/offline.
class OnboardingPhoto extends StatelessWidget {
  final String asset;
  final double size;
  final bool cutout;

  const OnboardingPhoto({
    super.key,
    required this.asset,
    required this.size,
    this.cutout = false,
  });

  @override
  Widget build(BuildContext context) {
    final photo = Image.asset(
      asset,
      width: size,
      height: size,
      fit: cutout ? BoxFit.contain : BoxFit.cover,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(
        1,
        1024,
      ),
      excludeFromSemantics: true,
      gaplessPlayback: true,
    );
    return cutout ? photo : ClipOval(child: photo);
  }
}

class OnboardingAssets {
  static const bakery = 'assets/images/categories/firin.png';
  static const coffee = 'assets/images/categories/kafe.png';
  static const meal = 'assets/images/categories/restoran.png';
  static const dessert = 'assets/images/categories/pastane.png';
  static const produce = 'assets/images/categories/manav.png';
  static const sandwich = 'assets/images/categories/bufe.png';
  static const openBox = 'assets/images/food_box.png';
  static const closedBox = 'assets/images/onboarding/surprise-package.png';
  static const bag = 'assets/images/onboarding/rescue-bag.png';
  static const bin = 'assets/images/onboarding/waste-bin.png';
}
