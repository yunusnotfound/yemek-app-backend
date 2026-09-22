import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../data/models/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onCancel;

  const OrderCard({super.key, required this.order, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      'confirmed' => AppColors.successInk,
      'pending' || 'awaiting_payment' => AppColors.warningInk,
      'picked_up' => AppColors.infoInk,
      'cancelled' => AppColors.inkSoft,
      _ => AppColors.textSecondary,
    };
    final statusIcon = switch (order.status) {
      'confirmed' => Icons.check_circle_outline_rounded,
      'pending' => Icons.schedule_rounded,
      'awaiting_payment' => Icons.account_balance_wallet_outlined,
      'picked_up' => Icons.task_alt_rounded,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.receipt_long_outlined,
    };
    final showCode =
        !order.isAwaitingPayment &&
        (order.isActive || order.isCompleted) &&
        order.pickupCode.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppDepth.border, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D704B32),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 15, color: statusColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          order.statusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(order.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AppCachedImage(
                    imageUrl: order.package?.imageUrl,
                    width: 76,
                    height: 82,
                    fit: BoxFit.cover,
                    placeholder: ColoredBox(
                      color: const Color(0xFFF5E7D8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/images/food_box.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.package?.business?.name ?? 'İşletme',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.package?.title ?? 'Sürpriz paket',
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${order.quantity} paket',
                            style: AppTypography.bodySmall,
                          ),
                          Text(
                            formatMoney(order.finalPrice),
                            style: AppTypography.h3.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showCode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: order.isActive
                      ? const Color(0xFFFFEBDD)
                      : const Color(0xFFF3EADF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Teslim alma kodu',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          order.pickupCode,
                          style: AppTypography.h3.copyWith(
                            color: AppColors.primaryInk,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (order.isActive) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Paketini alırken bu kodu işletmeye göster.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (order.canCancel && onCancel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showCancelDialog(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    textStyle: AppTypography.bodySmall,
                    padding: const EdgeInsets.fromLTRB(10, 12, 0, 0),
                    minimumSize: const Size(48, 44),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: const Text('Siparişi İptal Et'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) {
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
