import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/money_format.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/mini_bar_chart.dart';
import '../widgets/stat_card.dart';

class DashboardPage extends StatefulWidget {
  final String businessId;
  final void Function(int)? onTabSwitch;

  const DashboardPage({super.key, required this.businessId, this.onTabSwitch});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(
      LoadDashboard(businessId: widget.businessId),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<DashboardBloc, DashboardState>(
        buildWhen: (previous, current) =>
            previous.runtimeType != current.runtimeType ||
            current is DashboardLoaded,
        builder: (context, state) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<DashboardBloc>().add(
                LoadDashboard(businessId: widget.businessId),
              );
              await context.read<DashboardBloc>().stream.firstWhere(
                (s) => s is DashboardLoaded || s is DashboardError,
              );
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: AppColors.background,
                  pinned: true,
                  expandedHeight: 80,
                  flexibleSpace: const FlexibleSpaceBar(
                    titlePadding: EdgeInsets.only(
                      left: AppSpacing.screenPadding,
                      bottom: AppSpacing.md,
                    ),
                    title: Text('Dashboard', style: AppTypography.h3),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => context.read<DashboardBloc>().add(
                        LoadDashboard(businessId: widget.businessId),
                      ),
                    ),
                  ],
                ),
                if (state is DashboardLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (state is DashboardError)
                  SliverFillRemaining(
                    child: _ErrorView(
                      message: state.message,
                      onRetry: () => context.read<DashboardBloc>().add(
                        LoadDashboard(businessId: widget.businessId),
                      ),
                    ),
                  )
                else if (state is DashboardLoaded)
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Today's quick stats
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Bugün Sipariş',
                                value: '${state.stats.todayOrders}',
                                icon: Icons.today,
                                iconColor: AppColors.info,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: StatCard(
                                label: 'Bugün Kazanç',
                                value: formatMoney(state.stats.todayRevenue),
                                icon: Icons.attach_money,
                                iconColor: AppColors.success,
                                valueColor: AppColors.success,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Bekleyen',
                                value: '${state.stats.pendingOrders}',
                                icon: Icons.pending_outlined,
                                iconColor: AppColors.warning,
                                valueColor: state.stats.pendingOrders > 0
                                    ? AppColors.warning
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: StatCard(
                                label: 'Ort. Puan',
                                value: state.stats.averageRating > 0
                                    ? state.stats.averageRating.toStringAsFixed(
                                        1,
                                      )
                                    : '-',
                                icon: Icons.star_outline,
                                iconColor: AppColors.warning,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Toplam Sipariş',
                                value: '${state.stats.totalOrders}',
                                icon: Icons.shopping_bag_outlined,
                                iconColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: StatCard(
                                label: 'Toplam Kazanç',
                                value: formatMoney(state.stats.totalRevenue),
                                icon: Icons.account_balance_wallet_outlined,
                                iconColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Weekly / Monthly revenue row
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Haftalık',
                                value: formatMoney(state.stats.weeklyRevenue),
                                icon: Icons.calendar_view_week,
                                iconColor: AppColors.info,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: StatCard(
                                label: 'Aylık',
                                value: formatMoney(state.stats.monthlyRevenue),
                                icon: Icons.calendar_month,
                                iconColor: AppColors.info,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // 7-day bar chart
                        MiniBarChart(dailyStats: state.stats.dailyStats),

                        const SizedBox(height: AppSpacing.md),

                        // Quick actions
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.receipt_long_outlined,
                                label: 'Siparişleri Gör',
                                onTap: () => widget.onTabSwitch?.call(1),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.inventory_2_outlined,
                                label: 'Paketleri Yönet',
                                onTap: () => widget.onTabSwitch?.call(2),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.xl),
                      ]),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
