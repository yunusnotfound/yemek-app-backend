import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/models/package_model.dart';
import '../../data/repositories/businesses_repository_impl.dart';
import '../../data/datasources/businesses_remote_datasource.dart';
import '../bloc/reservation_bloc.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../widgets/package_info_card.dart';
import '../widgets/reservation_confirm_sheet.dart';
import 'reservation_success_page.dart';
import '../../../payment/presentation/pages/payment_page.dart';

class PackageDetailPage extends StatelessWidget {
  final PackageModel package;

  const PackageDetailPage({super.key, required this.package});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReservationBloc(
        repository: BusinessesRepositoryImpl(
          remoteDataSource: BusinessesRemoteDataSource(dioClient: appDioClient),
        ),
      ),
      child: _PackageDetailView(package: package),
    );
  }
}

class _PackageDetailView extends StatelessWidget {
  final PackageModel package;

  const _PackageDetailView({required this.package});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReservationBloc, ReservationState>(
      listener: (context, state) {
        if (state is ReservationSuccess) {
          Navigator.of(context).pop(); // Close confirm sheet if open
          final payment = state.payment;
          if (payment != null && payment.required) {
            // Ücretli sipariş -> önce ödeme ekranı, başarı olunca pickup kodu gösterilir.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PaymentPage(
                  payment: payment,
                  package: package,
                  reservation: state.reservation,
                ),
              ),
            );
          } else {
            // Ücretsiz sipariş -> doğrudan başarı ekranı.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ReservationSuccessPage(
                  reservation: state.reservation,
                  package: package,
                  message: state.message,
                ),
              ),
            );
          }
        } else if (state is ReservationError) {
          Navigator.of(context).pop(); // Close confirm sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            // Hero Image with AppBar
            _buildSliverAppBar(context),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business info row
                    _buildBusinessHeader(),
                    const SizedBox(height: AppSpacing.md),

                    // Package title & description
                    _buildPackageInfo(),
                    const SizedBox(height: AppSpacing.lg),

                    // Price section
                    _buildPriceSection(),
                    const SizedBox(height: AppSpacing.lg),

                    // Pickup time & stock
                    _buildPickupSection(),
                    const SizedBox(height: AppSpacing.lg),

                    // Business details card
                    PackageInfoCard(business: package.business),

                    // Bottom padding for sticky button
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomButton(context),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    FavoritesBloc? favBloc;
    try {
      favBloc = context.read<FavoritesBloc>();
    } catch (_) {
      // FavoritesBloc not available in this route
    }

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.surface,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
      ),
      actions: [
        if (favBloc != null)
          BlocBuilder<FavoritesBloc, FavoritesState>(
            bloc: favBloc,
            builder: (context, favState) {
              // Bloc'un her zaman güncel olan listesinden oku; araya giren
              // marker state'lerde (Add/RemoveSuccess) kalp titremesin.
              final isFav = favBloc!.isFavorite(package.business.id);

              return GestureDetector(
                onTap: () {
                  favBloc!.add(ToggleFavorite(businessId: package.business.id));
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? AppColors.error : AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              );
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            package.imageUrl != null
                ? AppCachedImage(
                    imageUrl: package.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),

            // Discount badge
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '-%${package.discountPercentage} indirim',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Rating badge
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [
                    BoxShadow(color: AppColors.shadow, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      package.business.rating.toStringAsFixed(1),
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.divider,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              package.business.category.name,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHeader() {
    return Row(
      children: [
        // Business avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              package.business.name.isNotEmpty
                  ? package.business.name[0].toUpperCase()
                  : '?',
              style: AppTypography.h3.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                package.business.name,
                style: AppTypography.h3.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    package.business.category.name,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (package.business.distance != null) ...[
                    Text(
                      ' • ',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                    Icon(
                      Icons.location_on,
                      size: 13,
                      color: AppColors.textHint,
                    ),
                    Text(
                      ' ${package.business.distance!.toStringAsFixed(1)} km',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(package.title, style: AppTypography.h2),
        if (package.description != null && package.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            package.description!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceSection() {
    final savings = package.originalPrice - package.discountedPrice;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₺${package.originalPrice.toStringAsFixed(0)}',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textHint,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₺${package.discountedPrice.toStringAsFixed(0)}',
                style: AppTypography.h1.copyWith(
                  color: AppColors.primary,
                  fontSize: 28,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Text(
                  '₺${savings.toStringAsFixed(0)}',
                  style: AppTypography.h3.copyWith(color: AppColors.success),
                ),
                Text(
                  'tasarruf',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupSection() {
    String formattedDate;
    try {
      final date = DateTime.parse(package.pickupDate);
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        formattedDate = 'Bugun';
      } else {
        formattedDate = DateFormat('d MMMM yyyy', 'tr_TR').format(date);
      }
    } catch (_) {
      formattedDate = package.pickupDate;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pickup time
          _buildDetailRow(
            icon: Icons.access_time,
            iconColor: AppColors.primary,
            title: 'Teslim Alma Saati',
            value: package.formattedPickupTime,
          ),
          const Divider(height: 24, color: AppColors.divider),

          // Pickup date
          _buildDetailRow(
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.info,
            title: 'Tarih',
            value: formattedDate,
          ),
          const Divider(height: 24, color: AppColors.divider),

          // Stock
          _buildDetailRow(
            icon: Icons.inventory_2_outlined,
            iconColor: package.remainingQuantity <= 3
                ? AppColors.error
                : AppColors.success,
            title: 'Kalan Stok',
            value: package.remainingQuantity <= 3
                ? 'Son ${package.remainingQuantity} paket!'
                : '${package.remainingQuantity} paket',
            valueColor: package.remainingQuantity <= 3
                ? AppColors.error
                : AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(title, style: AppTypography.bodyMedium)),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    final isOutOfStock = package.remainingQuantity <= 0;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isOutOfStock ? null : () => _showConfirmSheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.divider,
            disabledForegroundColor: AppColors.textHint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: Text(
            isOutOfStock ? 'Tukendi' : 'Rezerve Et',
            style: AppTypography.button.copyWith(
              fontSize: 18,
              color: isOutOfStock ? AppColors.textHint : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmSheet(BuildContext context) {
    final bloc = context.read<ReservationBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: ReservationConfirmSheet(package: package),
      ),
    );
  }
}
