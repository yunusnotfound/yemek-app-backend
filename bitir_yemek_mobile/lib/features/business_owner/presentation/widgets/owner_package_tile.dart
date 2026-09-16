import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../data/models/owner_package_model.dart';

class OwnerPackageTile extends StatelessWidget {
  final OwnerPackageModel package;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const OwnerPackageTile({
    super.key,
    required this.package,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(package.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      confirmDismiss: (_) async {
        return await _showDeleteConfirmation(context);
      },
      onDismissed: (_) => onDelete?.call(),
      child: AppSurface(
        onTap: onTap,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row + active badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    package.title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _ActiveBadge(isActive: package.isActive),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // Pickup date + time
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${package.pickupDate}  ${hhmm(package.pickupStart)}-${hhmm(package.pickupEnd)}',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Stats row
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InfoPill(
                  icon: Icons.inventory_2_outlined,
                  label: '${package.remainingQuantity}/${package.quantity}',
                  color: package.remainingQuantity > 0
                      ? AppColors.successInk
                      : AppColors.error,
                ),
                _InfoPill(
                  icon: Icons.shopping_bag_outlined,
                  label: '${package.soldQuantity} satıldı',
                  color: AppColors.infoInk,
                ),
                Text(
                  formatMoney(package.discountedPrice),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '%${package.discountPercent} indirim',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.successInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) {
    return AppDialog.confirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Paketi sil',
      message: '"${package.title}" paketini silmek istediğinize emin misiniz?',
      confirmLabel: 'Sil',
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final bool isActive;

  const _ActiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.textHint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: AppTypography.bodySmall.copyWith(
          color: isActive ? AppColors.successInk : AppColors.textHint,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
