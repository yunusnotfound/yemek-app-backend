import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../data/datasources/businesses_remote_datasource.dart';
import '../../data/repositories/businesses_repository_impl.dart';
import '../bloc/packages_bloc.dart';
import '../widgets/package_card.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import 'package_detail_page.dart';

class AllPackagesPage extends StatelessWidget {
  final String title;
  final double latitude;
  final double longitude;

  const AllPackagesPage({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PackagesBloc(
        repository: BusinessesRepositoryImpl(
          remoteDataSource: BusinessesRemoteDataSource(
            dioClient: appDioClient,
          ),
        ),
      )..add(LoadNearbyPackages(latitude: latitude, longitude: longitude)),
      child: AllPackagesView(
        title: title,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
}

class AllPackagesView extends StatefulWidget {
  final String title;
  final double latitude;
  final double longitude;

  const AllPackagesView({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AllPackagesView> createState() => _AllPackagesViewState();
}

class _AllPackagesViewState extends State<AllPackagesView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= (maxScroll * 0.9)) {
      context.read<PackagesBloc>().add(
        LoadMorePackages(
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<PackagesBloc, PackagesState>(
        buildWhen: (previous, current) =>
            previous.runtimeType != current.runtimeType ||
            current is PackagesLoaded ||
            current is PackagesLoadingMore,
        builder: (context, state) {
          if (state is PackagesLoading) {
            return _buildShimmerLoading();
          }

          if (state is PackagesError && state.packages == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    state.message,
                    style: AppTypography.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () {
                      context.read<PackagesBloc>().add(
                        LoadNearbyPackages(
                          latitude: widget.latitude,
                          longitude: widget.longitude,
                        ),
                      );
                    },
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            );
          }

          if (state is PackagesLoaded ||
              (state is PackagesError && state.packages != null) ||
              state is PackagesLoadingMore) {
            final packages = state is PackagesLoaded
                ? state.packages
                : state is PackagesError
                ? state.packages!
                : (state as PackagesLoadingMore).packages;

            final isLoadingMore = state is PackagesLoadingMore;

            if (packages.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Henüz paket bulunmuyor', style: AppTypography.h3),
                  ],
                ),
              );
            }

            return BlocBuilder<FavoritesBloc, FavoritesState>(
              // Favori durumu kart içindeki FavoriteButton'da izleniyor;
              // liste favori değişiminde rebuild olmaz.
              buildWhen: (previous, current) => false,
              builder: (context, favState) {
                final favIds = favState is FavoritesLoaded
                    ? favState.favorites.map((f) => f.businessId).toSet()
                    : favState is FavoritesLoadingMore
                    ? favState.favorites.map((f) => f.businessId).toSet()
                    : <String>{};

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<PackagesBloc>().add(
                      LoadNearbyPackages(
                        latitude: widget.latitude,
                        longitude: widget.longitude,
                      ),
                    );
                  },
                  color: AppColors.primary,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    itemCount: packages.length + (isLoadingMore ? 1 : 0),
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
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                            final favBloc = context.read<FavoritesBloc>();
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
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
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
}
