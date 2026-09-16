import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme.dart';
import '../../../core/utils/money_format.dart';
import 'coupons_cubit.dart';
import 'coupons_page.dart';

class CampaignBanner extends StatelessWidget {
  final double latitude, longitude;
  const CampaignBanner({
    super.key,
    required this.latitude,
    required this.longitude,
  });
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CouponsCubit()..load(),
    child: BlocBuilder<CouponsCubit, CouponsState>(
      builder: (context, state) {
        final offers = state.wallet?.available ?? [];
        if (offers.isEmpty || state.error != null) {
          return const SizedBox.shrink();
        }
        final offer = offers.first;
        final value = offer.discountType == 'fixed'
            ? formatMoney(offer.discountValue, compact: true)
            : '%${offer.discountValue.toStringAsFixed(0)}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Container(
            decoration: AppDepth.surface(warm: true, radius: AppRadius.xl),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                onTap: () async {
                  final cubit = context.read<CouponsCubit>();
                  await openCoupons(
                    context,
                    latitude: latitude,
                    longitude: longitude,
                  );
                  if (!cubit.isClosed) cubit.load();
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.firstOrderOnly
                                  ? 'İLK PAKETİNE ÖZEL'
                                  : 'SANA BİR FIRSAT VAR',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.inkSoft,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '$value indirim',
                              style: AppTypography.h2.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${formatMoney(offer.minOrderAmount, compact: true)} ve üzeri · Seçili işletmeler',
                              style: AppTypography.bodySmall,
                            ),
                            if (offer.maxDiscountAmount != null &&
                                offer.discountType == 'percentage')
                              Text(
                                'En fazla ${formatMoney(offer.maxDiscountAmount!)}',
                                style: AppTypography.bodySmall,
                              ),
                            const SizedBox(height: 10),
                            Text(
                              'Fırsatları gör',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 64,
                        height: 72,
                        decoration: AppDepth.surface(radius: 20),
                        child: const Icon(
                          Icons.local_offer_rounded,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
