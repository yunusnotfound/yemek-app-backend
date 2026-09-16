import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../core/utils/money_format.dart';
import '../../home/data/models/package_model.dart';
import '../../home/data/models/reservation_model.dart';
import '../data/coupons_repository.dart';

class PackageCouponOffer extends StatefulWidget {
  final PackageModel package;
  final void Function(CouponModel, int) onSelected;
  const PackageCouponOffer({
    super.key,
    required this.package,
    required this.onSelected,
  });
  @override
  State<PackageCouponOffer> createState() => _PackageCouponOfferState();
}

class _PackageCouponOfferState extends State<PackageCouponOffer> {
  CouponModel? _coupon;
  double? _price;
  int _quantity = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = CouponsRepository();
    try {
      final wallet = await repository.wallet();
      final offers =
          wallet.available
              .where(
                (c) => c.fits(
                  widget.package.businessId,
                  widget.package.discountedPrice *
                      widget.package.remainingQuantity.clamp(0, 100),
                ),
              )
              .toList()
            ..sort(
              (a, b) => b
                  .calculateDiscount(widget.package.discountedPrice)
                  .compareTo(
                    a.calculateDiscount(widget.package.discountedPrice),
                  ),
            );
      for (final offer in offers) {
        final quantity = offer.minimumQuantity(widget.package.discountedPrice);
        try {
          final response = await repository.dio.post(
            '/coupons/validate',
            data: {
              'code': offer.code,
              'packageId': widget.package.id,
              'quantity': quantity,
            },
          );
          final price = (response.data['finalPrice'] as num?)?.toDouble();
          if (mounted && price != null) {
            setState(() {
              _coupon = offer;
              _price = price;
              _quantity = quantity;
            });
          }
          break;
        } catch (_) {
          /* A budget may have closed after the wallet request. */
        }
      }
    } catch (_) {
      /* Coupon availability must not block the normal checkout. */
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_coupon == null || _price == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppDepth.border),
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.creamTop,
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: () => widget.onSelected(_coupon!, _quantity),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Icon(Icons.local_offer_outlined, size: 18),
            Text(
              '${_quantity > 1 ? '$_quantity paket · ' : ''}${_coupon!.code} ile ${formatMoney(_price!)}',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text('Kuponu kullan'),
          ],
        ),
      ),
    );
  }
}
