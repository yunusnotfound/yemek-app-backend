import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/utils/money_format.dart';
import '../../home/data/models/reservation_model.dart';

class CouponTile extends StatelessWidget {
  final CouponModel coupon;
  final VoidCallback? onTap;
  final String action;
  final String? unavailableReason;
  const CouponTile({
    super.key,
    required this.coupon,
    this.onTap,
    this.action = 'Uygun paketleri gör',
    this.unavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    final value = coupon.discountType == 'fixed'
        ? formatMoney(coupon.discountValue, compact: true)
        : '%${coupon.discountValue.toStringAsFixed(0)}';
    final reason =
        unavailableReason ?? (!coupon.eligible ? coupon.reason : null);
    return Container(
      decoration: AppDepth.surface(warm: reason == null, radius: AppRadius.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  coupon.title ??
                      (coupon.firstOrderOnly
                          ? 'İlk paketine özel'
                          : 'Sana bir fırsat var'),
                  style: AppTypography.h3.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$value indirim',
            style: AppTypography.h1.copyWith(
              color: AppColors.ink,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (coupon.firstOrderOnly) 'İlk siparişinde',
              if (coupon.minOrderAmount > 0)
                '${formatMoney(coupon.minOrderAmount, compact: true)} ve üzeri',
              if (coupon.businessIds.isNotEmpty) 'Seçili işletmelerde',
              if (coupon.maxDiscountAmount != null &&
                  coupon.discountType == 'percentage')
                'En fazla ${formatMoney(coupon.maxDiscountAmount!)}',
              if (coupon.perUserLimit != null)
                'Kişi başı ${coupon.perUserLimit} kullanım',
            ].join(' · '),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppDepth.border),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                coupon.code,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              if (coupon.expiresAt != null)
                Text(
                  '${DateFormat('dd.MM.yyyy').format(coupon.expiresAt!.toLocal())} tarihine kadar',
                  style: AppTypography.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (reason != null)
            Text(reason, style: AppTypography.bodyMedium)
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(action),
              ),
            ),
        ],
      ),
    );
  }
}
