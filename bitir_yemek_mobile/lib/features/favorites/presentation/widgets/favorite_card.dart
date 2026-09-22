import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../data/models/favorite_model.dart';

class FavoriteCard extends StatelessWidget {
  final FavoriteModel favorite;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const FavoriteCard({
    super.key,
    required this.favorite,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photoHeight = 118 + (MediaQuery.textScalerOf(context).scale(12) - 12);
    final category = favorite.categoryName?.trim();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
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
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppDepth.border, width: 0.8),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: photoHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppCachedImage(
                      imageUrl: favorite.imageUrl,
                      height: photoHeight,
                      fit: BoxFit.cover,
                      placeholder: _placeholder(),
                      loadingWidget: _placeholder(),
                    ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x18000000),
                              Colors.transparent,
                              Color(0x20000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (category != null && category.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 14,
                        right: 68,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xF5FFF9F2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              category,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton(
                        tooltip: 'Favorilerden kaldır',
                        onPressed: onRemove == null
                            ? null
                            : () => _showRemoveDialog(context),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.all(6),
                        ),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0x65000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 23,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    if (favorite.fullAddress.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              favorite.fullAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EBDC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (favorite.rating > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 17,
                                  color: AppColors.successInk,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  favorite.rating.toStringAsFixed(1),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Paketleri keşfet',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primaryInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppColors.primaryInk,
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _placeholder() => ColoredBox(
    color: const Color(0xFFF3E4D5),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Image.asset(
        'assets/images/food_box.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );

  void _showRemoveDialog(BuildContext context) {
    AppDialog.confirm(
      context,
      icon: Icons.heart_broken_rounded,
      title: 'Favorilerden kaldır',
      message: '${favorite.businessName} favorilerinizden kaldırılsın mı?',
      cancelLabel: 'Vazgeç',
      confirmLabel: 'Kaldır',
    ).then((confirmed) {
      if (confirmed) onRemove?.call();
    });
  }
}
