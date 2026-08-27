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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Image section
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Business image
                    AppCachedImage(
                      imageUrl: favorite.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: _buildPlaceholderImage(),
                    ),

                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Remove button
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: GestureDetector(
                        onTap: () => _showRemoveDialog(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 20,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),

                    // Category badge
                    if (favorite.categoryName != null)
                      Positioned(
                        bottom: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            favorite.categoryName!,
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business name + rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          favorite.businessName,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildRatingBadge(),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Address
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          favorite.fullAddress,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildRatingBadge() {
    if (favorite.rating <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.warning),
          const SizedBox(width: 2),
          Text(
            favorite.rating.toStringAsFixed(1),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(BuildContext context) {
    AppDialog.confirm(
      context,
      icon: Icons.heart_broken_rounded,
      title: 'Favorilerden kaldir',
      message: '${favorite.businessName} favorilerinizden kaldirilsin mi?',
      cancelLabel: 'Vazgec',
      confirmLabel: 'Kaldir',
    ).then((confirmed) {
      if (confirmed) onRemove?.call();
    });
  }
}
