import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_artwork_image.dart';

/// Bundled previews keep the introduction available before sign-in/offline.
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
    final photo = AppArtworkImage(
      asset,
      width: size,
      height: size,
      fit: cutout ? BoxFit.contain : BoxFit.cover,
    );
    return cutout ? photo : ClipOval(child: photo);
  }
}

class OnboardingAssets {
  static const bakery = 'assets/images/categories/firin.webp';
  static const coffee = 'assets/images/categories/kafe.webp';
  static const meal = 'assets/images/categories/restoran.webp';
  static const dessert = 'assets/images/categories/pastane.webp';
  static const produce = 'assets/images/categories/manav.webp';
  static const sandwich = 'assets/images/categories/bufe.webp';
  static const openBox = 'assets/images/food_box.png';
  static const bag = 'assets/images/onboarding/rescue-bag.webp';
  static const bin = 'assets/images/onboarding/waste-bin.webp';
}
