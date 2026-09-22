import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../data/models/business_model.dart';
import '../../data/models/package_model.dart';

class HomeBusinessCard extends StatelessWidget {
  final BusinessModel business;
  final VoidCallback onTap;

  const HomeBusinessCard({
    super.key,
    required this.business,
    required this.onTap,
  });

  static double carouselHeight(BuildContext context) =>
      220 + (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 60) * 6;

  @override
  Widget build(BuildContext context) {
    final distance = business.distance;
    final distanceLabel = distance == null
        ? ''
        : distance < 1
        ? '${(distance * 1000).round()} m'
        : '${distance.toStringAsFixed(1)} km';
    final location = [
      if (business.district.isNotEmpty) business.district,
      if (distanceLabel.isNotEmpty) distanceLabel,
    ].join(' · ');
    final textGrowth = MediaQuery.textScalerOf(context).scale(12) - 12;
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 76).clamp(240, 290),
      child: _CardSurface(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120 + textGrowth,
              child: Stack(
                children: [
                  SizedBox(
                    height: 98,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Photo(
                          url: business.imageUrl,
                          height: 98,
                          icon: Icons.storefront_rounded,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x18000000),
                                Colors.transparent,
                                Color(0x35000000),
                              ],
                              stops: [0, 0.5, 1],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    right: 60,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF2FFF9F2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          business.category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: FavoriteButton(
                      businessId: business.id,
                      size: 24,
                      inactiveColor: Colors.white,
                      activeColor: Colors.white,
                      backgroundColor: const Color(0x55000000),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 0,
                    child: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9F2),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x15704B32),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: AppCachedImage(
                          imageUrl: business.imageUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          placeholder: ColoredBox(
                            color: const Color(0xFFF5E4D3),
                            child: Center(
                              child: Text(
                                business.name.isEmpty
                                    ? 'B'
                                    : business.name.characters.first
                                          .toUpperCase(),
                                style: AppTypography.h3.copyWith(
                                  color: AppColors.primaryInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EADD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            business.rating > 0
                                ? Icons.star_rounded
                                : Icons.auto_awesome_rounded,
                            size: 14,
                            color: const Color(0xFFA77032),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            business.rating > 0
                                ? business.rating.toStringAsFixed(1)
                                : 'Yeni',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(
                        fontSize: 17,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location.isEmpty ? business.city : location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 4, 5, 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6E8DA),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 17,
                            color: AppColors.primaryInk,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Paketleri keşfet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primaryInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeProductCard extends StatelessWidget {
  final PackageModel package;
  final VoidCallback onTap;

  const HomeProductCard({
    super.key,
    required this.package,
    required this.onTap,
  });

  String get _pickupDay {
    final date = DateTime.tryParse(package.pickupDate);
    if (date == null) return package.pickupDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Bugün';
    if (day == today.add(const Duration(days: 1))) return 'Yarın';
    return DateFormat('dd.MM').format(day);
  }

  static const _ink = Color(0xFF252D2B);
  static const _green = Color(0xFF005B50);

  TextStyle _type(
    double size, {
    Color color = _ink,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: size,
    height: 1.2,
    color: color,
    fontWeight: weight,
  );

  String get _distance {
    final distance = package.business.distance;
    if (distance == null) return '';
    return distance < 1
        ? '${(distance * 1000).round()} m'
        : '${distance.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D704B32),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFFFFF9F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFEEDFD2), width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final height =
                      (constraints.maxWidth / 3.7).clamp(90.0, 180.0) +
                      (largeText ? 50 : 0);
                  return SizedBox(
                    height: height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Photo(
                          url: package.imageUrl,
                          height: height,
                          icon: Icons.shopping_bag_outlined,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x14000000),
                                Color(0x99000000),
                              ],
                              stops: [0, 0.35, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          right: 58,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    package.remainingQuantity > 0 &&
                                        package.remainingQuantity <= 5
                                    ? const Color(0xFFFFFFCC)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                package.remainingQuantity > 0
                                    ? '${package.remainingQuantity} paket kaldı'
                                    : 'Tükendi',
                                style: _type(12, weight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: FavoriteButton(
                            businessId: package.business.id,
                            size: 26,
                            inactiveColor: Colors.white,
                            activeColor: Colors.white,
                            backgroundColor: const Color(0x66000000),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 12,
                          bottom: 9,
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: ClipOval(
                                  child: AppCachedImage(
                                    imageUrl: package.business.imageUrl,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                    placeholder: Center(
                                      child: Text(
                                        package.business.name.isEmpty
                                            ? 'B'
                                            : package
                                                  .business
                                                  .name
                                                  .characters
                                                  .first
                                                  .toUpperCase(),
                                        style: _type(
                                          21,
                                          color: _green,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  package.business.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _type(
                                    16,
                                    color: Colors.white,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _type(16, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Teslim al: ${_pickupDay.toLowerCase()} ${package.formattedPickupTime}',
                      style: _type(13),
                    ),
                    const SizedBox(height: 5),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final rating = Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 17,
                                  height: 17,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF509A80),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  package.business.rating > 0
                                      ? package.business.rating.toStringAsFixed(
                                          1,
                                        )
                                      : 'Yeni',
                                  style: _type(13, weight: FontWeight.w700),
                                ),
                              ],
                            ),
                            if (_distance.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 17,
                                    width: 1,
                                    color: const Color(0xFFDDDFDE),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _distance,
                                    style: _type(13, weight: FontWeight.w700),
                                  ),
                                ],
                              ),
                          ],
                        );
                        final prices = Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (package.originalPrice > package.discountedPrice)
                              Text(
                                formatMoney(package.originalPrice),
                                style: _type(12, color: const Color(0xFF8C9390))
                                    .copyWith(
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                            const SizedBox(height: 5),
                            Text(
                              formatMoney(package.discountedPrice),
                              style: _type(
                                21,
                                color: _green,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                        if (largeText || constraints.maxWidth < 280) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              rating,
                              Align(
                                alignment: Alignment.centerRight,
                                child: prices,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: rating,
                              ),
                            ),
                            const SizedBox(width: 8),
                            prices,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _CardSurface({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D704B32),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: const Color(0xFFFFF9F2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEEDFD2), width: 0.8),
      ),
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}

class _Photo extends StatelessWidget {
  final String? url;
  final double height;
  final IconData icon;
  const _Photo({required this.url, required this.height, required this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: AppCachedImage(
      imageUrl: url,
      height: height,
      fit: BoxFit.cover,
      placeholder: ColoredBox(
        color: AppColors.divider,
        child: Icon(icon, color: AppColors.textHint, size: 32),
      ),
    ),
  );
}
