import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../bloc/orders_bloc.dart';
import '../widgets/order_card.dart';

class OrdersPage extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const OrdersPage({super.key, this.onNavigateToHome});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Lazy load: only fire the API call the first time this tab is visited
    final bloc = context.read<OrdersBloc>();
    if (bloc.state is OrdersInitial) {
      bloc.add(const LoadOrders());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<OrdersBloc>().add(const LoadMoreOrders());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                0,
              ),
              child: Text('Siparişlerim', style: AppTypography.h2),
            ),
            const SizedBox(height: AppSpacing.md),

            // Filter tabs
            BlocBuilder<OrdersBloc, OrdersState>(
              buildWhen: (prev, curr) {
                if (curr is OrdersLoaded || curr is OrdersLoadingMore) {
                  return true;
                }
                return false;
              },
              builder: (context, state) {
                final currentFilter = state is OrdersLoaded
                    ? state.filter
                    : state is OrdersLoadingMore
                    ? state.filter
                    : OrderFilter.active;
                return _buildFilterTabs(currentFilter);
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // Content
            Expanded(
              child: BlocConsumer<OrdersBloc, OrdersState>(
                listener: (context, state) {
                  if (state is OrderCancelSuccess) {
                    AppNotice.success(context, 'Siparis iptal edildi');
                  } else if (state is OrderCancelError) {
                    AppNotice.error(context, state.message);
                  }
                },
                buildWhen: (prev, curr) {
                  return curr is! OrderCancelSuccess &&
                      curr is! OrderCancelError;
                },
                builder: (context, state) {
                  if (state is OrdersLoading) {
                    return _buildShimmerLoading();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<OrdersBloc>().add(const RefreshOrders());
                    },
                    color: AppColors.primary,
                    child: _buildContent(state),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(OrdersState state) {
    if (state is OrdersError) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(child: _buildErrorState(state.message))],
      );
    }

    if (state is OrdersLoaded || state is OrdersLoadingMore) {
      final filteredOrders = state is OrdersLoaded
          ? state.filteredOrders
          : (state as OrdersLoadingMore).filteredOrders;
      final isLoadingMore = state is OrdersLoadingMore;
      final hasMore =
          state is OrdersLoadingMore ||
          (state is OrdersLoaded && !state.hasReachedMax);
      final filter = state is OrdersLoaded
          ? state.filter
          : (state as OrdersLoadingMore).filter;

      if (filteredOrders.isEmpty) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                filter,
                hasMore: hasMore,
                isLoadingMore: isLoadingMore,
              ),
            ),
          ],
        );
      }

      return ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.sm,
        ),
        itemCount: filteredOrders.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filteredOrders.length) {
            return _buildLoadMore(isLoadingMore);
          }

          final order = filteredOrders[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: OrderCard(
              order: order,
              onCancel: order.canCancel
                  ? () {
                      context.read<OrdersBloc>().add(
                        CancelOrder(orderId: order.id),
                      );
                    }
                  : null,
            ),
          );
        },
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: const [SliverFillRemaining()],
    );
  }

  Widget _buildFilterTabs(OrderFilter currentFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Aktif',
            icon: Icons.schedule,
            isSelected: currentFilter == OrderFilter.active,
            onTap: () => context.read<OrdersBloc>().add(
              const ChangeOrderFilter(filter: OrderFilter.active),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(
            label: 'Geçmiş',
            icon: Icons.check_circle_outline,
            isSelected: currentFilter == OrderFilter.completed,
            onTap: () => context.read<OrdersBloc>().add(
              const ChangeOrderFilter(filter: OrderFilter.completed),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip(
            label: 'İptal Edilen',
            icon: Icons.cancel_outlined,
            isSelected: currentFilter == OrderFilter.cancelled,
            onTap: () => context.read<OrdersBloc>().add(
              const ChangeOrderFilter(filter: OrderFilter.cancelled),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? AppColors.primaryInk : AppColors.textSecondary,
      ),
      label: Text(label),
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: isSelected ? AppColors.primaryInk : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.10),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: isSelected ? AppColors.sand : AppDepth.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
    );
  }

  Widget _buildLoadMore(bool isLoadingMore) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: isLoadingMore
            ? const CircularProgressIndicator(color: AppColors.primary)
            : OutlinedButton.icon(
                onPressed: () =>
                    context.read<OrdersBloc>().add(const LoadMoreOrders()),
                icon: const Icon(Icons.expand_more),
                label: const Text('Diğer siparişleri yükle'),
              ),
      ),
    );
  }

  Widget _buildEmptyState(
    OrderFilter filter, {
    required bool hasMore,
    required bool isLoadingMore,
  }) {
    String title;
    String subtitle;
    IconData icon;

    switch (filter) {
      case OrderFilter.active:
        title = 'Aktif siparişiniz yok';
        subtitle = 'Yeni bir sürpriz paket keşfetmeye ne dersiniz?';
        icon = Icons.shopping_bag_outlined;
        break;
      case OrderFilter.completed:
        title = 'Tamamlanan siparişiniz yok';
        subtitle = 'Teslim aldığınız siparişler burada görünecek';
        icon = Icons.check_circle_outline;
        break;
      case OrderFilter.cancelled:
        title = 'İptal edilen siparişiniz yok';
        subtitle = 'İptal ettiğiniz siparişler burada görünecek';
        icon = Icons.cancel_outlined;
        break;
    }

    if (hasMore) {
      title = 'Diğer siparişlerinizi kontrol edin';
      subtitle =
          'Bu filtrede henüz sipariş görünmüyor. Önceki siparişlerinizi yükleyerek devam edebilirsiniz.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasMore) _buildLoadMore(isLoadingMore),
            if (!hasMore && filter == OrderFilter.active) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: widget.onNavigateToHome,
                icon: const Icon(Icons.explore),
                label: const Text('Keşfe Başla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                context.read<OrdersBloc>().add(const LoadOrders());
              },
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerLoader(
            isLoading: true,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        );
      },
    );
  }
}
