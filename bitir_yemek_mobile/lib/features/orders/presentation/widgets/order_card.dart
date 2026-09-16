import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../data/models/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onCancel;

  const OrderCard({super.key, required this.order, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: business name + status badge
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                // Business avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      order.package?.business?.name.isNotEmpty == true
                          ? order.package!.business!.name[0].toUpperCase()
                          : '?',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.package?.business?.name ?? 'İşletme',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildStatusBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Package title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                order.package?.title ?? 'Paket',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Divider
          const Divider(height: 1, color: AppColors.divider),

          // Bottom section: pickup code, date, price
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!order.isAwaitingPayment &&
                        (order.isActive || order.isCompleted))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        decoration: AppDepth.iconTile(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.qr_code,
                              size: 18,
                              color: AppColors.primaryInk,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              order.pickupCode,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primaryInk,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      _formatDate(order.createdAt),
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Toplam', style: AppTypography.bodySmall),
                    Text(
                      formatMoney(order.finalPrice),
                      style: AppTypography.h3.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cancel button for active orders
          if (order.canCancel && onCancel != null) ...[
            const Divider(height: 1, color: AppColors.divider),
            InkWell(
              onTap: () => _showCancelDialog(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, size: 16, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      'Siparişi İptal Et',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;

    switch (order.status) {
      case 'pending':
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warningInk;
        break;
      case 'confirmed':
        bgColor = AppColors.info.withValues(alpha: 0.1);
        textColor = AppColors.infoInk;
        break;
      case 'picked_up':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.successInk;
        break;
      case 'cancelled':
        bgColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        break;
      default:
        bgColor = AppColors.divider;
        textColor = AppColors.textHint;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        order.statusText,
        style: AppTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Bugün, ${DateFormat('HH:mm').format(date)}';
    }
    return DateFormat('d MMM, HH:mm', 'tr_TR').format(date);
  }

  void _showCancelDialog(BuildContext context) {
    AppDialog.confirm(
      context,
      icon: Icons.event_busy_rounded,
      title: 'Siparişi iptal et',
      message: 'Bu siparişi iptal etmek istediğinizden emin misiniz?',
      cancelLabel: 'Vazgeç',
      confirmLabel: 'İptal Et',
    ).then((confirmed) {
      if (confirmed) onCancel?.call();
    });
  }
}
