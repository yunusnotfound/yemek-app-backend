import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../../home/data/datasources/businesses_remote_datasource.dart';
import '../../../home/data/repositories/businesses_repository_impl.dart';
import '../../../home/presentation/pages/package_detail_page.dart';
import '../../../home/presentation/widgets/package_card.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_bar.dart';
import '../widgets/sort_dropdown.dart';

class SearchPage extends StatelessWidget {
  final double latitude;
  final double longitude;

  const SearchPage({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(
        repository: BusinessesRepositoryImpl(
          remoteDataSource: BusinessesRemoteDataSource(
            dioClient: appDioClient,
          ),
        ),
      )..add(SearchPackages(latitude: latitude, longitude: longitude)),
      child: SearchView(latitude: latitude, longitude: longitude),
    );
  }
}

class SearchView extends StatefulWidget {
  final double latitude;
  final double longitude;

  const SearchView({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<SearchBloc>().add(
        LoadMoreSearchResults(
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
      );
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
          children: [
            // Search Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  // Search Bar
                  CustomSearchBar(
                    controller: _searchController,
                    onChanged: (value) {
                      context.read<SearchBloc>().add(
                        SearchPackages(
                          latitude: widget.latitude,
                          longitude: widget.longitude,
                          query: value.trim().isEmpty ? null : value.trim(),
                        ),
                      );
                    },
                    onSubmitted: (value) {
                      context.read<SearchBloc>().add(
                        SearchPackages(
                          latitude: widget.latitude,
                          longitude: widget.longitude,
                          query: value.trim().isEmpty ? null : value.trim(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Sort
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BlocBuilder<SearchBloc, SearchState>(
                        builder: (context, state) {
                          if (state is SearchLoaded) {
                            return SortDropdown(
                              currentSort: state.sortOrder,
                              onChanged: (sortOrder) {
                                context.read<SearchBloc>().add(
                                  UpdateSortOrder(sortOrder: sortOrder),
                                );
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: BlocConsumer<SearchBloc, SearchState>(
                listener: (context, state) {
                  if (state is SearchError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is SearchLoading) {
                    return _buildShimmerLoading();
                  }

                  if (state is SearchError) {
                    return _buildErrorState();
                  }

                  if (state is SearchLoaded || state is SearchLoadingMore) {
                    final packages = state is SearchLoaded
                        ? state.packages
                        : (state as SearchLoadingMore).packages;
                    final isLoadingMore = state is SearchLoadingMore;

                    if (packages.isEmpty) {
                      return _buildEmptyState();
                    }

                    return BlocBuilder<FavoritesBloc, FavoritesState>(
                      // Favori durumu kart içindeki FavoriteButton'da izleniyor;
                      // liste favori değişiminde rebuild olmaz.
                      buildWhen: (previous, current) => false,
                      builder: (context, favState) {
                        final favIds = favState is FavoritesLoaded
                            ? favState.favorites
                                  .map((f) => f.businessId)
                                  .toSet()
                            : favState is FavoritesLoadingMore
                            ? favState.favorites
                                  .map((f) => f.businessId)
                                  .toSet()
                            : <String>{};

                        return RefreshIndicator(
                          onRefresh: () async {
                            context.read<SearchBloc>().add(
                              SearchPackages(
                                latitude: widget.latitude,
                                longitude: widget.longitude,
                              ),
                            );
                          },
                          color: AppColors.primary,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenPadding,
                            ),
                            itemCount:
                                packages.length + (isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= packages.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: PackageCard(
                                  package: packages[index],
                                  isHorizontal: false,
                                  isFavorite: favIds.contains(
                                    packages[index].business.id,
                                  ),
                                  onFavoriteTap: () {
                                    context.read<FavoritesBloc>().add(
                                      ToggleFavorite(
                                        businessId: packages[index].business.id,
                                      ),
                                    );
                                  },
                                  onTap: () {
                                    final favBloc = context
                                        .read<FavoritesBloc>();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BlocProvider.value(
                                          value: favBloc,
                                          child: PackageDetailPage(
                                            package: packages[index],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerLoader(
            isLoading: true,
            child: Container(
              height: 120,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Sonuç bulunamadı',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Farklı arama kriterleri deneyin\nveya konumunuzu değiştirin',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () {
              context.read<SearchBloc>().add(
                SearchPackages(
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Bir hata oluştu',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Lütfen tekrar deneyin',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () {
              context.read<SearchBloc>().add(
                SearchPackages(
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}
