import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme.dart';
import '../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../home/data/models/package_model.dart';
import '../../home/data/models/reservation_model.dart';
import 'coupons_cubit.dart';
import 'coupon_tile.dart';
import 'coupon_packages_page.dart';

Future<CouponModel?> openCoupons(
  BuildContext context, {
  PackageModel? package,
  int quantity = 1,
  double? latitude,
  double? longitude,
}) {
  // The checkout bottom sheet may not inherit FavoritesBloc; selection needs no cards.
  FavoritesBloc? favorites;
  try {
    favorites = context.read<FavoritesBloc>();
  } catch (_) {
    /* optional in checkout */
  }
  Widget page = CouponsPage(
    package: package,
    quantity: quantity,
    latitude: latitude,
    longitude: longitude,
  );
  if (favorites != null) {
    page = BlocProvider.value(value: favorites, child: page);
  }
  return Navigator.of(
    context,
  ).push<CouponModel>(MaterialPageRoute(builder: (_) => page));
}

class CouponsPage extends StatelessWidget {
  final PackageModel? package;
  final int quantity;
  final double? latitude, longitude;
  const CouponsPage({
    super.key,
    this.package,
    this.quantity = 1,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CouponsCubit()..load(),
    child: Scaffold(
      appBar: AppBar(title: Text(package == null ? 'Kuponlarım' : 'Kupon seç')),
      body: BlocBuilder<CouponsCubit, CouponsState>(
        builder: (context, state) {
          if (state.loading && state.wallet == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final coupons = state.wallet?.coupons ?? const <CouponModel>[];
          return RefreshIndicator(
            onRefresh: context.read<CouponsCubit>().load,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: coupons.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Bir paket, biraz daha mutluluk.',
                        style: AppTypography.h2.copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Koşulları incele, sana uygun fırsatı seç. Her siparişte bir kupon kullanabilirsin.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (state.error != null) ...[
                        Text(state.error!, style: AppTypography.bodyMedium),
                        TextButton(
                          onPressed: context.read<CouponsCubit>().load,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                      if (state.wallet != null && state.wallet!.coupons.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: AppDepth.surface(warm: true),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                size: 40,
                                color: AppColors.inkSoft,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Yeni fırsatlar burada seni bekleyecek.',
                                style: AppTypography.h3,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Şu anda aktif kampanya yok. Paketlerin mevcut indirimlerinden yararlanmaya devam edebilirsin.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }
                final coupon = coupons[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: CouponTile(
                    coupon: coupon,
                    action: package == null
                        ? 'Uygun paketleri gör'
                        : 'Bu kuponu seç',
                    unavailableReason:
                        package != null &&
                            coupon.eligible &&
                            !coupon.fits(
                              package!.businessId,
                              package!.discountedPrice * quantity,
                            )
                        ? 'Bu paket kampanyanın işletme veya minimum tutar koşulunu karşılamıyor.'
                        : null,
                    onTap: () async {
                      if (package != null) {
                        Navigator.of(context).pop(coupon);
                        return;
                      }
                      final cubit = context.read<CouponsCubit>();
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<FavoritesBloc>(),
                            child: CouponPackagesPage(
                              coupon: coupon,
                              latitude: latitude,
                              longitude: longitude,
                            ),
                          ),
                        ),
                      );
                      if (!cubit.isClosed) cubit.load();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );
}
