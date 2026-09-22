import '../../../coupons/presentation/campaign_banner.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../data/models/category_model.dart';
import '../bloc/home_bloc.dart';
import '../bloc/packages_bloc.dart';
import '../widgets/category_tiles.dart';
import '../widgets/location_header.dart';
import '../widgets/home_catalog_cards.dart';
import '../../data/models/business_model.dart';
import '../widgets/packages_empty_state.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import 'package_detail_page.dart';
import 'business_detail_page.dart';

class HomePage extends StatelessWidget {
  final double latitude;
  final double longitude;

  const HomePage({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    // PackagesBloc ve HomeBloc artık MainScaffold'da sağlanıyor; bu sayfa Ara
    // sekmesine geçilince yeniden kurulduğu için bloc'u burada yaratmak her
    // dönüşte aynı veriyi tekrar ağdan çekiyordu. İlk yükleme initState'te;
    // sonraki sessiz güncellemeler MainScaffold'daki CatalogRefresh ile yapılır.
    return HomeView(latitude: latitude, longitude: longitude);
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
  int _selectedCategoryIndex = 0;
  List<CategoryModel> _categories = [];
  final _scrollController = ScrollController();

  /// Seçili kategori id'si (null = "Hepsi"). Pull-to-refresh bunu kullanır.
  String? _currentCategoryId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMore);

    // Bloc'lar sekmeler arası paylaşıldığı için veri zaten yüklenmiş olabilir.
    // Burada yalnız ilk yükleme yapılır; CatalogRefresh görünür sekmenin
    // güncellemelerini devam eden isteklerle çakıştırmadan tetikler.
    final packagesBloc = context.read<PackagesBloc>();
    if (packagesBloc.state is PackagesInitial) {
      packagesBloc.add(
        LoadNearbyPackages(
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
      );
    }

    final homeBloc = context.read<HomeBloc>();
    if (homeBloc.state is HomeInitial) {
      homeBloc.add(LoadCategories());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 400) {
      return;
    }
    final bloc = context.read<PackagesBloc>();
    final state = bloc.state;
    if (state is PackagesLoaded && !state.hasReachedMax) {
      bloc.add(
        LoadMorePackages(
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
      );
    }
  }

  void _onCategorySelected(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });

    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (_categories.isEmpty) return;

    final categoryId = _categories[index].id == 0
        ? null
        : _categories[index].id.toString();
    _currentCategoryId = categoryId;

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
                  return CategoryTiles(
                    categories: state.categories,
                    selectedIndex: _selectedCategoryIndex,
                    onCategorySelected: _onCategorySelected,
                  );
                }
                if (state is HomeLoading) {
                  // Kategori şeridi yüklenirken: kutucuklarla AYNI ölçülerde
                  // iskelet. Aynı yükseklik/genişlik kullanılmazsa veri gelince
                  // sayfa zıplar.
                  return SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                        vertical: AppSpacing.xs,
                      ),
                      itemCount: 5,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) {
                        return ShimmerLoader(
                          isLoading: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                width: 60,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }
                if (state is HomeError) {
                  // Kategoriler alınamadıysa yalnız "Hepsi" göster; sayfa
                  // kategorisiz de çalışmaya devam etsin.
                  return CategoryTiles(
                    categories: const [
                      CategoryModel(id: 0, name: 'Hepsi', slug: 'all'),
                    ],
                    selectedIndex: 0,
                    onCategorySelected: (_) {},
                  );
                }
                return const SizedBox(height: 132);
              },
            ),

            // Content
            Expanded(
              child: BlocConsumer<PackagesBloc, PackagesState>(
                listener: (context, state) {
                  if (state is PackagesError) {
                    AppNotice.error(context, state.message);
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
                                RefreshPackages(
                                  latitude: widget.latitude,
                                  longitude: widget.longitude,
                                  categoryId: _currentCategoryId,
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

                    if (packages.isEmpty) {
                      return _buildEmptyState();
                    }

                    final businesses = <String, BusinessModel>{};
                    for (final package in packages) {
                      businesses.putIfAbsent(
                        package.business.id,
                        () => package.business,
                      );
                    }
                    final nearbyBusinesses = businesses.values.toList();

                    // Favori durumu her kartın içindeki FavoriteButton
                    // tarafından izleniyor; liste favori değişiminde rebuild
                    // olmaz (yalnız ilgili kalp yeniden çizilir).
                    return RefreshIndicator(
                      onRefresh: () async {
                        context.read<HomeBloc>().add(const RefreshCategories());
                        // Spinner, paketler oturana kadar dönsün. onDone,
                        // veri değişmese bile tamamlanır (state bastırılsa da).
                        final done = Completer<void>();
                        context.read<PackagesBloc>().add(
                          RefreshPackages(
                            latitude: widget.latitude,
                            longitude: widget.longitude,
                            categoryId: _currentCategoryId,
                            onDone: done,
                          ),
                        );
                        await done.future;
                      },
                      color: AppColors.primary,
                      child: CustomScrollView(
                        key: const PageStorageKey('home-catalog'),
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: CampaignBanner(
                              latitude: widget.latitude,
                              longitude: widget.longitude,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: Text(
                                'Yakınındaki fırsatlar',
                                style: AppTypography.h3.copyWith(fontSize: 17),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: HomeBusinessCard.carouselHeight(context),
                              child: ListView.separated(
                                key: const PageStorageKey('home-businesses'),
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: nearbyBusinesses.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final business = nearbyBusinesses[index];
                                  return HomeBusinessCard(
                                    key: ValueKey(business.id),
                                    business: business,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BusinessDetailPage(
                                          businessId: business.id,
                                          businessName: business.name,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                12,
                              ),
                              child: Text(
                                'Keşfetmeye devam et',
                                style: AppTypography.h3.copyWith(fontSize: 18),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList.builder(
                              itemCount: packages.length,
                              itemBuilder: (context, index) {
                                final package = packages[index];
                                return Padding(
                                  key: ValueKey(package.id),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: HomeProductCard(
                                    package: package,
                                    onTap: () {
                                      final favorites = context
                                          .read<FavoritesBloc>();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BlocProvider.value(
                                            value: favorites,
                                            child: PackageDetailPage(
                                              package: package,
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
                          if (state is PackagesLoadingMore)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),
                        ],
                      ),
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
    return PackagesEmptyState(
      onClearCategory: _currentCategoryId == null
          ? null
          : () => _onCategorySelected(0),
      onRefresh: () {
        context.read<HomeBloc>().add(const RefreshCategories());
        context.read<PackagesBloc>().add(
          RefreshPackages(
            latitude: widget.latitude,
            longitude: widget.longitude,
            categoryId: _currentCategoryId,
          ),
        );
      },
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
            height: HomeBusinessCard.carouselHeight(context),
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
                      width: 280,
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
