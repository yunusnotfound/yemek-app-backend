import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../data/models/package_model.dart';

class PackageCard extends StatelessWidget {
  final PackageModel package;
  final bool isHorizontal;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const PackageCard({
    super.key,
    required this.package,
    this.isHorizontal = false,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: isHorizontal ? _buildHorizontalCard() : _buildVerticalCard(),
    );
  }

  Widget _buildHorizontalCard() {
    return Container(
      width: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Görsel + rozetler + logo
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  color: AppColors.divider,
                  child: AppCachedImage(
                    imageUrl: package.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholderImage(),
                  ),
                ),
                // "N adet kaldı" rozeti (sol üst, düşük stokta)
                if (package.remainingQuantity <= 5)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _stockBadge(),
                  ),
                // Rating rozeti (sağ üst)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: _ratingBadge(),
                ),
                // İşletme logosu (sol alt)
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: _logoCircle(),
                ),
              ],
            ),
          ),

          // İçerik
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İşletme adı + favori
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        package.business.name,
                        style: AppTypography.h3.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FavoriteButton(businessId: package.business.id),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // Paket başlığı
                Text(
                  package.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                // Alım penceresi (tarih + saat + mesafe)
                _pickupRow(),
                const SizedBox(height: AppSpacing.sm),
                // İnce ayraç
                Container(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                // Fiyat (sağa hizalı)
                _priceRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEFD2), // krem
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '${package.remainingQuantity} adet kaldı',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _ratingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: AppColors.warning),
          const SizedBox(width: 2),
          Text(
            package.business.rating.toStringAsFixed(1),
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoCircle() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: AppCachedImage(
          imageUrl: package.business.imageUrl,
          fit: BoxFit.cover,
          placeholder: _buildPlaceholderImage(),
        ),
      ),
    );
  }

  Widget _pickupRow() {
    final dateLabel = _pickupDateLabel(package.pickupDate);
    final timeLabel = '${_hhmm(package.pickupStart)} - ${_hhmm(package.pickupEnd)}';
    final distance = package.business.distance;

    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: AppColors.textHint),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            dateLabel.isEmpty ? 'AL $timeLabel' : '$dateLabel AL $timeLabel',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (distance != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatDistance(distance),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ],
    );
  }

  Widget _priceRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Spacer(),
        Text(
          '₺${package.originalPrice.toStringAsFixed(0)}',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textHint,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '₺${package.discountedPrice.toStringAsFixed(0)}',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- Biçim yardımcıları ---

  String _hhmm(String time) => time.length >= 5 ? time.substring(0, 5) : time;

  String _formatDistance(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  String _pickupDateLabel(String pickupDate) {
    final parts = pickupDate.split('-');
    if (parts.length != 3) return '';
    final d = DateTime.tryParse(pickupDate);
    if (d == null) return '${parts[2]}.${parts[1]}';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '${parts[2]}.${parts[1]}';
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.divider,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 40,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              package.business.category.name,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalCard() {
    return Container(
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
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(AppRadius.lg),
            ),
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  color: AppColors.divider,
                  child: AppCachedImage(
                    imageUrl: package.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholderImage(),
                  ),
                ),
                // "N adet kaldı" rozeti (düşük stokta)
                if (package.remainingQuantity <= 5)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCEFD2), // krem
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${package.remainingQuantity} adet kaldı',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.business.name,
                          style: AppTypography.h3.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FavoriteButton(businessId: package.business.id),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    package.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Rating & Distance
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: AppColors.warning),
                      const SizedBox(width: 2),
                      Text(
                        package.business.rating.toStringAsFixed(1),
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${package.business.distance?.toStringAsFixed(1) ?? '?'} km',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₺${package.originalPrice.toStringAsFixed(0)}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textHint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '₺${package.discountedPrice.toStringAsFixed(0)}',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
