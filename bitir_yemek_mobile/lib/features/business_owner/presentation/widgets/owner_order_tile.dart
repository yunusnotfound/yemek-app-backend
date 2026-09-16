import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/time_format.dart';
import '../../data/models/owner_order_model.dart';

class OwnerOrderTile extends StatelessWidget {
  final OwnerOrderModel order;
  final VoidCallback? onVerifyTap;

  const OwnerOrderTile({super.key, required this.order, this.onVerifyTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDepth.surface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: customer name + status chip
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  order.user?.name ?? 'Bilinmeyen Müşteri',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Package title
          Text(
            order.package?.title ?? 'Bilinmeyen Paket',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                pickupWindow(
                  order.package?.pickupStart,
                  order.package?.pickupEnd,
                ),
                style: AppTypography.bodySmall,
              ),
              Text(
                formatMoney(order.totalPrice),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Pickup code row
          if (order.pickupCode.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.qr_code, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Kod: ${order.pickupCode}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryInk,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Verify button
          if (order.canVerify && onVerifyTap != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onVerifyTap,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Kodu Doğrula'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.successInk,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'confirmed':
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.infoInk;
        break;
      case 'picked_up':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.successInk;
        break;
      case 'cancelled':
        bg = AppColors.error.withValues(alpha: 0.15);
        fg = AppColors.error;
        break;
      default: // pending
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warningInk;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        _label(status),
        style: AppTypography.bodySmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  String _label(String status) {
    switch (status) {
      case 'confirmed':
        return 'Onaylı';
      case 'picked_up':
        return 'Teslim';
      case 'cancelled':
        return 'İptal';
      default:
        return 'Bekliyor';
    }
  }
}
