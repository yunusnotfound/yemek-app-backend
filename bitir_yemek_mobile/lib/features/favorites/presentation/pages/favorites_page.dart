import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../../home/presentation/pages/business_detail_page.dart';
import '../bloc/favorites_bloc.dart';
import '../widgets/favorite_card.dart';

class FavoritesPage extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const FavoritesPage({super.key, this.onNavigateToHome});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Lazy load: only fire the API call the first time this tab is visited
    final bloc = context.read<FavoritesBloc>();
    if (bloc.state is FavoritesInitial) {
      bloc.add(const LoadFavorites());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<FavoritesBloc>().add(const LoadMoreFavorites());
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
              child: Text('Favorilerim', style: AppTypography.h2),
            ),
            const SizedBox(height: AppSpacing.md),

            // Content
            Expanded(
              child: BlocConsumer<FavoritesBloc, FavoritesState>(
                listener: (context, state) {
                  if (state is FavoriteRemoveSuccess) {
                    AppNotice.success(context, 'Favorilerden kaldirildi');
                  } else if (state is FavoriteRemoveError) {
                    AppNotice.error(context, state.message);
                  }
                },
                buildWhen: (prev, curr) {
                  return curr is! FavoriteRemoveSuccess &&
                      curr is! FavoriteRemoveError;
                },
                builder: (context, state) {
                  if (state is FavoritesLoading) {
                    return _buildShimmerLoading();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<FavoritesBloc>().add(
                        const RefreshFavorites(),
                      );
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

  Widget _buildContent(FavoritesState state) {
    if (state is FavoritesError) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(child: _buildErrorState(state.message))],
      );
    }

    if (state is FavoritesLoaded || state is FavoritesLoadingMore) {
      final favorites = state is FavoritesLoaded
          ? state.favorites
          : (state as FavoritesLoadingMore).favorites;
      final isLoadingMore = state is FavoritesLoadingMore;

      if (favorites.isEmpty) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [SliverFillRemaining(child: _buildEmptyState())],
        );
      }

      return ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.sm,
        ),
        itemCount: favorites.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= favorites.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          final favorite = favorites[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FavoriteCard(
              favorite: favorite,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BusinessDetailPage(
                      businessId: favorite.businessId,
                      businessName: favorite.businessName,
                    ),
                  ),
                );
              },
              onRemove: () {
                context.read<FavoritesBloc>().add(
                  RemoveFavorite(businessId: favorite.businessId),
                );
              },
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

  Widget _buildEmptyState() {
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
                Icons.favorite_border,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Henuz favoriniz yok',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Begendginiz isletmeleri favorilere ekleyerek\nkolayca erisebilirsiniz',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: widget.onNavigateToHome,
              icon: const Icon(Icons.explore),
              label: const Text('Kesfe Basla'),
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
                context.read<FavoritesBloc>().add(const LoadFavorites());
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
              height: 220,
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
