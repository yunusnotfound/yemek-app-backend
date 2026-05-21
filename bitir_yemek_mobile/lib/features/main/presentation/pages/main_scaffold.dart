import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../home/data/datasources/businesses_remote_datasource.dart';
import '../../../home/data/repositories/businesses_repository_impl.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../../home/presentation/bloc/packages_bloc.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../orders/data/datasources/orders_remote_datasource.dart';
import '../../../orders/data/repositories/orders_repository_impl.dart';
import '../../../orders/presentation/bloc/orders_bloc.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../search/presentation/bloc/search_bloc.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../favorites/data/datasources/favorites_remote_datasource.dart';
import '../../../favorites/data/repositories/favorites_repository_impl.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';

class MainScaffold extends StatefulWidget {
  final double latitude;
  final double longitude;
  final int initialIndex;

  const MainScaffold({
    super.key,
    required this.latitude,
    required this.longitude,
    this.initialIndex = 0,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;
  late final TokenStorage _tokenStorage;
  late final DioClient _dioClient;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Create shared instances for auth interceptor
    _tokenStorage = createDefaultTokenStorage();
    _dioClient = DioClient(tokenStorage: _tokenStorage);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Home Blocs
        BlocProvider(
          create: (context) =>
              PackagesBloc(
                repository: BusinessesRepositoryImpl(
                  remoteDataSource: BusinessesRemoteDataSource(
                    dioClient: _dioClient,
                  ),
                ),
              )..add(
                LoadNearbyPackages(
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                ),
              ),
        ),
        BlocProvider(
          create: (context) => HomeBloc(
            repository: BusinessesRepositoryImpl(
              remoteDataSource: BusinessesRemoteDataSource(
                dioClient: _dioClient,
              ),
            ),
          )..add(LoadCategories()),
        ),
        // Search Bloc
        BlocProvider(
          create: (context) => SearchBloc(
            repository: BusinessesRepositoryImpl(
              remoteDataSource: BusinessesRemoteDataSource(
                dioClient: _dioClient,
              ),
            ),
          ),
        ),
        // Orders Bloc
        BlocProvider(
          create: (context) {
            return OrdersBloc(
              repository: OrdersRepositoryImpl(
                remoteDataSource: OrdersRemoteDataSource(dioClient: _dioClient),
              ),
            );
          },
        ),
        // Favorites Bloc
        BlocProvider(
          create: (context) {
            return FavoritesBloc(
              repository: FavoritesRepositoryImpl(
                remoteDataSource: FavoritesRemoteDataSource(dioClient: _dioClient),
              ),
            );
          },
        ),
        // Profile Bloc
        BlocProvider(
          create: (context) {
            return ProfileBloc(
              profileRepository: ProfileRepositoryImpl(
                remoteDataSource: ProfileRemoteDataSource(dioClient: _dioClient),
                tokenStorage: _tokenStorage,
              ),
            )..add(LoadProfile());
          },
        ),
      ],
      child: Scaffold(
        body: _buildBody(),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    // MapPage uses a native PlatformView (Mapbox GL) that requires being
    // visible when created. IndexedStack builds all children eagerly which
    // prevents the GL surface from initialising off-screen.
    // We show MapPage directly when selected, and keep the other pages in
    // an IndexedStack so they preserve state across tab switches.
    if (_currentIndex == 2) {
      return MapPage(
        latitude: widget.latitude,
        longitude: widget.longitude,
        dioClient: _dioClient,
      );
    }

    // Map the visual index to IndexedStack index (0,1 stay the same; 3,4,5 → 2,3,4)
    final stackIndex = _currentIndex > 2 ? _currentIndex - 1 : _currentIndex;

    return IndexedStack(
      index: stackIndex,
      children: [
        // 0 - Keşfet (Home)
        HomePage(latitude: widget.latitude, longitude: widget.longitude),
        // 1 - Ara (Search)
        SearchPage(latitude: widget.latitude, longitude: widget.longitude),
        // 2 - Sipariş (Orders)  [nav index 3]
        OrdersPage(
          onNavigateToHome: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        ),
        // 3 - Favoriler (Favorites)  [nav index 4]
        FavoritesPage(
          onNavigateToHome: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        ),
        // 4 - Profil (Profile)  [nav index 5]
        ProfilePage(
          onTabSwitch: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ],
    );
  }
}
