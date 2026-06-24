import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../data/datasources/businesses_remote_datasource.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/businesses_repository_impl.dart';
import '../bloc/home_bloc.dart';
import '../bloc/packages_bloc.dart';
import '../widgets/category_chips.dart';
import '../widgets/location_header.dart';
import '../widgets/package_card.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import 'package_detail_page.dart';
import 'all_packages_page.dart';

class HomePage extends StatelessWidget {
  final double latitude;
  final double longitude;

  const HomePage({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => PackagesBloc(
            repository: BusinessesRepositoryImpl(
              remoteDataSource: BusinessesRemoteDataSource(
                dioClient: appDioClient,
              ),
            ),
          )..add(LoadNearbyPackages(latitude: latitude, longitude: longitude)),
        ),
        BlocProvider(
          create: (context) => HomeBloc(
            repository: BusinessesRepositoryImpl(
              remoteDataSource: BusinessesRemoteDataSource(
                dioClient: appDioClient,
              ),
            ),
          )..add(LoadCategories()),
        ),
      ],
      child: HomeView(latitude: latitude, longitude: longitude),
    );
  }
}

class HomeView extends StatefulWidget {
  final double latitude;
  final double longitude;

  const HomeView({super.key, required this.latitude, required this.longitude});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ScrollController _scrollController = ScrollController();
  int _selectedCategoryIndex = 0;
  List<CategoryModel> _categories = [];

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
    if (_isBottom) {
      context.read<PackagesBloc>().add(
        LoadMorePackages(
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

  void _onCategorySelected(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });

    if (_categories.isEmpty) return;

    final categoryId = _categories[index].id == 0
        ? null
        : _categories[index].id.toString();

    if (categoryId == null) {
      context.read<PackagesBloc>().add(
        LoadNearbyPackages(
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
      );
    } else {
      context.read<PackagesBloc>().add(
        LoadPackagesByCategory(
          categoryId: categoryId,
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
      body: SafeArea(
        child: Column(
          children: [
            // Location Header
            LocationHeader(
              latitude: widget.latitude,
              longitude: widget.longitude,
            ),

            // Category Chips
            BlocBuilder<HomeBloc, HomeState>(
              buildWhen: (previous, current) =>
                  previous.runtimeType != current.runtimeType ||
                  current is HomeLoaded,
              builder: (context, state) {
                if (state is HomeLoaded) {
                  _categories = state.categories;
                  return CategoryChips(
                    categories: state.categories.map((c) => c.name).toList(),
                    selectedIndex: _selectedCategoryIndex,
                    onCategorySelected: _onCategorySelected,
                  );
                }
                if (state is HomeLoading) {
                  // Shimmer loading for categories
                  return SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                        vertical: AppSpacing.xs,
                      ),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ShimmerLoader(
                            isLoading: true,
                            child: Container(
                              width: 80,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                if (state is HomeError) {
                  // Show only "Hepsi" category on error
                  return CategoryChips(
                    categories: const ['Hepsi'],
                    selectedIndex: 0,
                    onCategorySelected: (_) {},
                  );
                }
                return const SizedBox(height: 56);
              },
            ),

            // Content
            Expanded(
              child: BlocConsumer<PackagesBloc, PackagesState>(
                listener: (context, state) {
                  if (state is PackagesError && state.packages == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is PackagesLoading) {
                    return _buildShimmerLoading();
                  }

                  if (state is PackagesError && state.packages == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.error,
                          ),
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
                      return _buildEmptyState();
                    }

                    return BlocBuilder<FavoritesBloc, FavoritesState>(
                      // Favori durumu artık her kartın içindeki FavoriteButton
                      // tarafından izleniyor; liste favori değişiminde rebuild olmaz
                      // (yalnız ilgili kalp yeniden çizilir).
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
                            context.read<PackagesBloc>().add(
                              LoadNearbyPackages(
                                latitude: widget.latitude,
                                longitude: widget.longitude,
                              ),
                            );
                          },
                          color: AppColors.primary,
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              // Popular Section Title
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenPadding,
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Yakınınızdaki popüler seçimler',
                                          style: AppTypography.h3.copyWith(
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          final favBloc = context
                                              .read<FavoritesBloc>();
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => BlocProvider.value(
                                                value: favBloc,
                                                child: AllPackagesPage(
                                                  title:
                                                      'Yakınınızdaki Popüler Seçimler',
                                                  latitude: widget.latitude,
                                                  longitude: widget.longitude,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'Hepsini Gör',
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Horizontal Package List
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 290,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.screenPadding,
                                    ),
                                    itemCount: packages.length > 5
                                        ? 5
                                        : packages.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: AppSpacing.md,
                                        ),
                                        child: PackageCard(
                                          package: packages[index],
                                          isHorizontal: true,
                                          isFavorite: favIds.contains(
                                            packages[index].business.id,
                                          ),
                                          onFavoriteTap: () {
                                            context.read<FavoritesBloc>().add(
                                              ToggleFavorite(
                                                businessId:
                                                    packages[index].business.id,
                                              ),
                                            );
                                          },
                                          onTap: () {
                                            final favBloc = context
                                                .read<FavoritesBloc>();
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    BlocProvider.value(
                                                      value: favBloc,
                                                      child: PackageDetailPage(
                                                        package:
                                                            packages[index],
                                                      ),
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Local Best Section Title
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenPadding,
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Yerel En İyiler',
                                          style: AppTypography.h3.copyWith(
                                            fontSize: 18,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          final favBloc = context
                                              .read<FavoritesBloc>();
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  BlocProvider.value(
                                                    value: favBloc,
                                                    child: AllPackagesPage(
                                                      title: 'Yerel En İyiler',
                                                      latitude: widget.latitude,
                                                      longitude:
                                                          widget.longitude,
                                                    ),
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'Hepsini Gör',
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Vertical Package List
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screenPadding,
                                ),
                                sliver: SliverList.builder(
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
                                              businessId:
                                                  packages[index].business.id,
                                            ),
                                          );
                                        },
                                        onTap: () {
                                          final favBloc = context
                                              .read<FavoritesBloc>();
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  BlocProvider.value(
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
                              ),
                            ],
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
              Icons.shopping_bag_outlined,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Henüz paket bulunmuyor',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Yakınınızdaki restoranlardan\nsürpriz paketler yakında burada!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () {
              context.read<PackagesBloc>().add(
                LoadNearbyPackages(
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return CustomScrollView(
      slivers: [
        // Section Title Shimmer
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: ShimmerLoader(
              isLoading: true,
              child: Container(
                width: 200,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
        ),
        // Horizontal Cards Shimmer
        SliverToBoxAdapter(
          child: SizedBox(
            height: 310,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: ShimmerLoader(
                    isLoading: true,
                    child: Container(
                      width: 240,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Second Section Title Shimmer
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: ShimmerLoader(
              isLoading: true,
              child: Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
        ),
        // Vertical Cards Shimmer
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          sliver: SliverList.builder(
            itemCount: 3,
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
          ),
        ),
      ],
    );
  }
}
