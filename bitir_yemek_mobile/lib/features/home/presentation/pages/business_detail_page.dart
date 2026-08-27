import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/datasources/businesses_remote_datasource.dart';
import '../../data/models/business_detail_model.dart';
import '../../data/models/package_model.dart';
import '../../data/repositories/businesses_repository_impl.dart';
import '../../domain/repositories/businesses_repository.dart';
import '../pages/package_detail_page.dart';

class BusinessDetailPage extends StatefulWidget {
  final String businessId;
  final String? businessName;

  const BusinessDetailPage({
    super.key,
    required this.businessId,
    this.businessName,
  });

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage> {
  late final BusinessesRepository _repository;
  BusinessDetailModel? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = BusinessesRepositoryImpl(
      remoteDataSource: BusinessesRemoteDataSource(
        dioClient: appDioClient,
      ),
    );
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _repository.getBusinessDetail(widget.businessId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _detail = result.detail;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          title: Text(widget.businessName ?? 'Isletme'),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error ?? 'Bir hata olustu',
                  style: AppTypography.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _loadDetail,
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final detail = _detail!;

    return RefreshIndicator(
      onRefresh: _loadDetail,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Hero image app bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.surface,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppCachedImage(
                    imageUrl: detail.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholderImage(),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  // Category badge
                  Positioned(
                    bottom: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        detail.category.name,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  if (detail.rating > 0)
                    Positioned(
                      bottom: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              detail.averageRating.toStringAsFixed(1),
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Business info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(detail.name, style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.xs),

                  // Description
                  if (detail.description != null &&
                      detail.description!.isNotEmpty) ...[
                    Text(
                      detail.description!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Bir bakışta özet: puan / paket / değerlendirme.
                  _buildStatStrip(detail),
                  const SizedBox(height: AppSpacing.md),

                  // Address
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    '${detail.address}, ${detail.fullAddress}',
                  ),
                  if (detail.phone != null && detail.phone!.isNotEmpty)
                    _buildInfoRow(Icons.phone_outlined, detail.phone!),

                  const SizedBox(height: AppSpacing.sm),
                  _buildActionButtons(detail),

                  const SizedBox(height: AppSpacing.lg),
                  const Divider(color: AppColors.divider),
                ],
              ),
            ),
          ),

          // Packages section
          if (detail.packages.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                ),
                // Sayı rozeti, Değerlendirmeler bölümündeki kalıbın aynısı —
                // iki başlık artık aynı dili konuşuyor.
                child: Row(
                  children: [
                    Text('Mevcut Paketler', style: AppTypography.h3),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${detail.packages.length}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final pkg = detail.packages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.xs,
                  ),
                  child: _buildPackageCard(pkg),
                );
              }, childCount: detail.packages.length),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          ],

          // No packages message
          if (detail.packages.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Su anda mevcut paket bulunmuyor',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Reviews section
          if (detail.reviews.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text('Degerlendirmeler', style: AppTypography.h3),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${detail.reviews.length}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final review = detail.reviews[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.xs,
                  ),
                  child: _buildReviewCard(review),
                );
              }, childCount: detail.reviews.length),
            ),
          ],

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  /// İsmin hemen altındaki özet şerit: puan / paket / değerlendirme.
  ///
  /// Sayfa açıldığında göz, isim ile adres arasında tutunacak bir şey
  /// bulamıyordu. Buradaki üç değer de zaten çekilen veriden geliyor, ek istek
  /// yok — sadece daha önce gösterilmiyorlardı.
  Widget _buildStatStrip(BusinessDetailModel detail) {
    final puanVar = detail.reviews.isNotEmpty || detail.rating > 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCell(
              icon: Icons.star_rounded,
              iconColor: AppColors.warning,
              value: puanVar ? detail.averageRating.toStringAsFixed(1) : 'Yeni',
              label: 'Puan',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatCell(
              icon: Icons.shopping_bag_rounded,
              iconColor: AppColors.primary,
              value: '${detail.packages.length}',
              label: 'Paket',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatCell(
              icon: Icons.chat_bubble_rounded,
              iconColor: AppColors.info,
              value: '${detail.reviews.length}',
              label: 'Yorum',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 32, color: AppColors.divider);
  }

  /// Yol tarifi + arama. Ekran şimdiye kadar adresi ve telefonu yalnız METİN
  /// olarak gösteriyordu; kullanıcı numarayı elle kopyalamak zorundaydı.
  Widget _buildActionButtons(BusinessDetailModel detail) {
    final telefonVar = detail.phone != null && detail.phone!.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.directions_rounded,
            label: 'Yol Tarifi',
            onTap: () => _openDirections(detail),
            dolgulu: true,
          ),
        ),
        if (telefonVar) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildActionButton(
              icon: Icons.phone_rounded,
              label: 'Ara',
              onTap: () => _callBusiness(detail.phone!),
              dolgulu: false,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool dolgulu,
  }) {
    return Material(
      color: dolgulu ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: dolgulu
                ? null
                : Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: dolgulu ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.button.copyWith(
                  fontSize: 15,
                  color: dolgulu ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Harita sayfasındaki (_onNavigate) sıralamanın aynısı: önce Google Maps
  /// uygulaması, sonra Apple Haritalar, en son tarayıcı.
  Future<void> _openDirections(BusinessDetailModel detail) async {
    final hedefler = [
      'comgooglemaps://?daddr=${detail.latitude},${detail.longitude}&directionsmode=driving',
      'maps://maps.apple.com/?daddr=${detail.latitude},${detail.longitude}&dirflg=d',
      'https://www.google.com/maps/dir/?api=1&destination=${detail.latitude},${detail.longitude}&travelmode=driving',
    ];
    for (final hedef in hedefler) {
      final uri = Uri.parse(hedef);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  Future<void> _callBusiness(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(PackageModel pkg) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PackageDetailPage(package: pkg)),
        );
      },
      child: Container(
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
            // Package image
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 72,
                height: 72,
                child: pkg.imageUrl != null && pkg.imageUrl!.isNotEmpty
                    ? AppCachedImage(
                        imageUrl: pkg.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: _buildSmallPlaceholder(),
                      )
                    : _buildSmallPlaceholder(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Package info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pkg.pickupStart} - ${pkg.pickupEnd}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${pkg.originalPrice.toStringAsFixed(0)} TL',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textHint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${pkg.discountedPrice.toStringAsFixed(0)} TL',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Discount badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '-%${pkg.discountPercentage}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
                        : '?',
                    style: AppTypography.bodySmall.copyWith(
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
                      review.userName,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'd MMM yyyy',
                        'tr_TR',
                      ).format(review.createdAt),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: AppColors.warning,
                  );
                }),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 64,
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildSmallPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 28,
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
