import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/theme.dart';
import '../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../home/data/models/package_model.dart';
import '../../home/data/models/reservation_model.dart';
import '../../home/presentation/pages/package_detail_page.dart';
import '../../home/presentation/widgets/package_card.dart';
import '../data/coupons_repository.dart';

class CouponPackagesPage extends StatefulWidget {
  final CouponModel coupon;
  final double? latitude, longitude;
  const CouponPackagesPage({
    super.key,
    required this.coupon,
    this.latitude,
    this.longitude,
  });
  @override
  State<CouponPackagesPage> createState() => _CouponPackagesPageState();
}

class _CouponPackagesPageState extends State<CouponPackagesPage> {
  final _repository = CouponsRepository();
  List<PackageModel> _packages = [];
  int _page = 0;
  bool _loading = false, _hasMore = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.packages(
        widget.coupon.id,
        page: reset ? 1 : _page + 1,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      if (!mounted) return;
      setState(() {
        _packages = reset ? result.data : [..._packages, ...result.data];
        _page = result.pagination.page;
        _hasMore = _page < result.pagination.totalPages;
      });
    } catch (e) {
      if (mounted) setState(() => _error = CouponsRepository.error(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.coupon.title ?? 'Kampanya paketleri')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            widget.latitude == null
                ? 'Seçili işletmelerden paketler'
                : 'Yakınındaki kampanya paketleri',
            style: AppTypography.h3,
          ),
          const SizedBox(height: 8),
          const Text(
            'Kuponunu sipariş onayında seçebilirsin. Son tutar ödeme öncesinde doğrulanır.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(reset: true),
              child: const Text('Tekrar dene'),
            ),
          ],
          if (!_loading && _error == null && _packages.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppDepth.surface(warm: true),
              child: const Text(
                'Şu anda koşullara uygun paket yok. Yeni paketler geldiğinde burada görünecek.',
                style: AppTypography.bodyLarge,
              ),
            ),
          for (final package in _packages)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: PackageCard(
                package: package,
                campaignLabel: widget.coupon.firstOrderOnly
                    ? '${widget.coupon.minimumQuantity(package.discountedPrice)} adet ile ilk sipariş fırsatı'
                    : '${widget.coupon.minimumQuantity(package.discountedPrice)} adet ile kupon fırsatı',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<FavoritesBloc>(),
                      child: PackageDetailPage(package: package),
                    ),
                  ),
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasMore && _error == null)
            TextButton(onPressed: _load, child: const Text('Daha fazla paket')),
        ],
      ),
    ),
  );
}
