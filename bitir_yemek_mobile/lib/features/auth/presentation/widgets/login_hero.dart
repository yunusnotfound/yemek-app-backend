import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_artwork_image.dart';

/// A food photograph connects sign-in to the food rescue experience.
class LoginHero extends StatelessWidget {
  const LoginHero({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 168,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8DEC7), Color(0xFFF1C4A3)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -30,
                  child: Container(
                    width: 206,
                    height: 206,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.creamTop.withValues(alpha: 0.32),
                    ),
                  ),
                ),
                Positioned(
                  right: -25,
                  bottom: -45,
                  child: Transform.rotate(
                    angle: -0.16,
                    child: const AppArtworkImage(
                      'assets/images/onboarding/foodbox-bakery.webp',
                      width: 205,
                      height: 205,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  top: 22,
                  bottom: 18,
                  width: constraints.maxWidth * 0.53,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: constraints.maxWidth * 0.53,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HER LOKMA DEĞERLİ',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryInk,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'İyi yemek.\nİyi hisset.',
                            style: AppTypography.h1.copyWith(
                              color: AppColors.ink,
                              fontSize: 31,
                              height: 1.04,
                              letterSpacing: -0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Lezzete bir şans daha.',
                            style: AppTypography.bodySmall.copyWith(
                              color: const Color(0xFF715038),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
