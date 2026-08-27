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
    // PackagesBloc ve HomeBloc artık MainScaffold'da sağlanıyor; bu sayfa Ara
    // sekmesine geçilince yeniden kurulduğu için bloc'u burada yaratmak her
    // dönüşte aynı veriyi tekrar ağdan çekiyordu. İlk yükleme
    // _HomeViewState.initState içinde, yalnız durum initial ise tetiklenir.
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

  /// Seçili kategori id'si (null = "Hepsi"). Pull-to-refresh bunu kullanır.
  String? _currentCategoryId;

  @override
  void initState() {
    super.initState();

    // Bloc'lar sekmeler arası paylaşıldığı için veri zaten yüklenmiş olabilir.
    // Yalnızca hiç yüklenmemişse ağa çık — sekmeye her dönüşte tekrar istek
    // atılmasını bu koşul engelliyor.
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

  /// İkinci bölümde ("Yerel En İyiler") gösterilecek kart sayısı.
  ///
  /// Üstteki bölüm ilk 5'i gösteriyor; bu bölüm listenin sonundan besleniyor.
  /// Toplam 5 veya altındaysa iki bölüm tamamen çakışacağı için en fazla
  /// `toplam - 5` kart gösterilir (yoksa hiç gösterilmez).
  int _sonSansSayisi(int toplam) {
    final kalan = toplam - 5;
    if (kalan <= 0) return 0;
    return kalan > 5 ? 5 : kalan;
  }

  void _onCategorySelected(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });

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
                  if (state is PackagesError && state.packages == null) {
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

                    if (packages.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Favori durumu her kartın içindeki FavoriteButton
                    // tarafından izleniyor; liste favori değişiminde rebuild
                    // olmaz (yalnız ilgili kalp yeniden çizilir).
                    return RefreshIndicator(
                          onRefresh: () async {
                            context.read<HomeBloc>().add(
                              const RefreshCategories(),
                            );
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
                                  height: 320,
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

                              // İkinci bölüm de yatay karusel. Keşfet artık
                              // dikey sonsuz liste değil, bölümlerden oluşuyor;
                              // tam liste "Hepsini Gör" ile açılan
                              // AllPackagesPage'de (sayfalama orada).
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 320,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.screenPadding,
                                    ),
                                    itemCount: _sonSansSayisi(packages.length),
                                    itemBuilder: (context, index) {
                                      // Bu bölüm listenin SONUNDAN besleniyor:
                                      // üstteki bölüm ilk 5'i gösterdiği için
                                      // aynı kartları tekrar etmesin.
                                      final pkg =
                                          packages[packages.length - 1 - index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: AppSpacing.md,
                                        ),
                                        child: PackageCard(
                                          package: pkg,
                                          isHorizontal: true,
                                          onTap: () {
                                            final favBloc = context
                                                .read<FavoritesBloc>();
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    BlocProvider.value(
                                                      value: favBloc,
                                                      child: PackageDetailPage(
                                                        package: pkg,
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
              context.read<HomeBloc>().add(const RefreshCategories());
              context.read<PackagesBloc>().add(
                RefreshPackages(
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  categoryId: _currentCategoryId,
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
