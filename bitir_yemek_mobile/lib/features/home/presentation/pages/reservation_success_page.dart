import 'package:flutter/material.dart';
import '../../../main/presentation/main_tab_navigation.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../config/theme.dart';
import '../../data/models/package_model.dart';
import '../../data/models/reservation_model.dart';

class ReservationSuccessPage extends StatefulWidget {
  final ReservationModel reservation;
  final PackageModel package;
  final String? message;

  const ReservationSuccessPage({
    super.key,
    required this.reservation,
    required this.package,
    this.message,
  });

  @override
  State<ReservationSuccessPage> createState() => _ReservationSuccessPageState();
}

class _ReservationSuccessPageState extends State<ReservationSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    (AppSpacing.screenPadding * 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Success animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            size: 64,
                            color: AppColors.success,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Rezervasyon tamamlandı!',
                          style: AppTypography.h2,
                          textAlign: TextAlign.center,
                        ),
                        if (widget.message != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            widget.message!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Pickup code
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Teslim Alma Kodu',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            widget.reservation.pickupCode,
                            style: AppTypography.h1.copyWith(
                              fontSize: 40,
                              color: AppColors.primary,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Paketini alırken bu kodu işletmeye göster.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Order summary
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
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
                          _buildSummaryRow(
                            Icons.shopping_bag_outlined,
                            widget.package.title,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSummaryRow(
                            Icons.store_outlined,
                            widget.package.business.name,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSummaryRow(
                            Icons.access_time,
                            widget.package.formattedPickupTime,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSummaryRow(
                            Icons.location_on_outlined,
                            widget.package.business.address,
                          ),
                          const Divider(height: 24, color: AppColors.divider),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.xs,
                            children: [
                              Text(
                                'Ödenen tutar',
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                formatMoney(widget.reservation.finalPrice),
                                style: AppTypography.h3.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Action buttons
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => _goToOrders(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Siparişlerime Git',
                              style: AppTypography.button,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => _goToHome(context),
                            child: Text(
                              'Ana Sayfaya Dön',
                              style: AppTypography.button.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textHint),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _goToOrders(BuildContext context) {
    // Pop back to MainScaffold and switch to orders tab (index 2)
    MainTabNavigation.returnTo(context, MainTab.orders);
  }

  void _goToHome(BuildContext context) {
    // Pop back to MainScaffold (home tab, index 0)
    MainTabNavigation.returnTo(context, MainTab.home);
  }
}
