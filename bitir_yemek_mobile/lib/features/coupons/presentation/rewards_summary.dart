import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme.dart';
import '../../../core/utils/money_format.dart';
import 'coupons_cubit.dart';
import 'coupons_page.dart';

class RewardsSummary extends StatelessWidget {
  const RewardsSummary({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CouponsCubit()..load(),
    child: BlocBuilder<CouponsCubit, CouponsState>(
      builder: (context, state) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: AppDepth.surface(warm: true, radius: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_outlined, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'İyilik birikiyor',
                    style: AppTypography.h3.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.wallet != null)
              Wrap(
                spacing: 28,
                runSpacing: 16,
                children: [
                  _metric(formatMoney(state.wallet!.saved), 'toplam tasarruf'),
                  _metric('${state.wallet!.rescued}', 'kurtarılan paket'),
                ],
              )
            else if (state.error != null)
              TextButton(
                onPressed: context.read<CouponsCubit>().load,
                child: const Text('Kazançlar yüklenemedi · Tekrar dene'),
              )
            else
              const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Tamamlanan siparişlerde kayıtlı indirimlerden hesaplanır.',
              style: AppTypography.bodySmall,
            ),
            const Divider(height: 28, color: AppDepth.border),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final cubit = context.read<CouponsCubit>();
                  await openCoupons(context);
                  if (!cubit.isClosed) cubit.load();
                },
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text(
                  'Kuponlarım${state.wallet == null ? '' : ' · ${state.wallet!.available.length} uygun fırsat'}',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppDepth.border),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _metric(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: AppTypography.h2.copyWith(color: AppColors.ink)),
      const SizedBox(height: 4),
      Text(label, style: AppTypography.bodySmall),
    ],
  );
}
