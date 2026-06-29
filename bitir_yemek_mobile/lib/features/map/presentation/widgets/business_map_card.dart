import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/package_model.dart';

class BusinessMapCard extends StatelessWidget {
  final BusinessModel business;
  final PackageModel? package;
  final bool packageLoading;
  final Map<String, dynamic>? directions;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onViewDetails;

  const BusinessMapCard({
    super.key,
    required this.business,
    this.package,
    this.packageLoading = false,
    this.directions,
    required this.onClose,
    required this.onNavigate,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Görsel bloğu (paket görseli + rozetler + logo)
                _buildImageBlock(),
                const SizedBox(height: AppSpacing.md),

                // İşletme adı + favori + kapat
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        business.name,
                        style: AppTypography.h3.copyWith(fontSize: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FavoriteButton(businessId: business.id, size: 24),
                    const SizedBox(width: AppSpacing.xs),
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.close,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Koleksiyon adı (paket başlığı) ya da kategori
                Text(
                  package?.title ?? business.category.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),

                // Alım penceresi + mesafe  /  paket yoksa not
                if (package != null)
                  _buildPickupRow(package!)
                else if (!packageLoading)
                  Text(
                    'Şu an müsait paket yok',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),

                // Fiyat satırı
                if (package != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildPriceRow(package!),
                ],

                // Yol tarifi bilgisi (mevcut)
                if (directions != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildDirectionsInfo(),
                ],

                // Aksiyon butonları (mevcut)
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewDetails,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: const Text('Detaylar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onNavigate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Yol Tarifi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildImageBlock() {
    final imageUrl = package?.imageUrl ?? business.imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: packageLoading
                ? Container(
                    color: AppColors.divider,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : AppCachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholder(),
                  ),
          ),

          // "N adet kaldı" rozeti (sol üst)
          if (package != null)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEFD2), // krem
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${package!.remainingQuantity} adet kaldı',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // Rating rozeti (sağ üst)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
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
                    business.rating.toStringAsFixed(1),
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // İşletme logosu (sol alt)
          Positioned(
            bottom: AppSpacing.sm,
            left: AppSpacing.sm,
            child: Container(
              width: 48,
              height: 48,
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
                  imageUrl: business.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: _buildPlaceholder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupRow(PackageModel pkg) {
    final dateLabel = _pickupDateLabel(pkg.pickupDate);
    final timeLabel =
        '${_hhmm(pkg.pickupStart)} - ${_hhmm(pkg.pickupEnd)}';

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
        if (business.distance != null) ...[
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
            _formatDistance(business.distance!),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceRow(PackageModel pkg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '₺${pkg.originalPrice.toStringAsFixed(0)}',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textHint,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '₺${pkg.discountedPrice.toStringAsFixed(0)}',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '-${pkg.discountPercentage}%',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Icon(
        _getCategoryIcon(),
        size: 28,
        color: AppColors.primary.withValues(alpha: 0.6),
      ),
    );
  }

  IconData _getCategoryIcon() {
    final categoryName = business.category.name.toLowerCase();
    if (categoryName.contains('restoran') ||
        categoryName.contains('restaurant')) {
      return Icons.restaurant;
    } else if (categoryName.contains('kafe') || categoryName.contains('cafe')) {
      return Icons.local_cafe;
    } else if (categoryName.contains('pastane') ||
        categoryName.contains('bakery')) {
      return Icons.bakery_dining;
    } else if (categoryName.contains('market')) {
      return Icons.store;
    }
    return Icons.storefront;
  }

  Widget _buildDirectionsInfo() {
    final distanceMeters = (directions?['distance'] as num?) ?? 0;
    final durationSeconds = (directions?['duration'] as num?) ?? 0;

    final distanceKm = distanceMeters / 1000;
    final durationMin = (durationSeconds / 60).round();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.straighten, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            distanceKm < 1
                ? '${distanceMeters.round()} m'
                : '${distanceKm.toStringAsFixed(1)} km',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(Icons.access_time, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$durationMin dk',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcılar ---

  /// "HH:MM:SS" → "HH:MM"
  String _hhmm(String time) =>
      time.length >= 5 ? time.substring(0, 5) : time;

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
}
