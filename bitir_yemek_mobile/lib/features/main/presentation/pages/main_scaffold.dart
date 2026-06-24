import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../orders/data/datasources/orders_remote_datasource.dart';
import '../../../orders/data/repositories/orders_repository_impl.dart';
import '../../../orders/presentation/bloc/orders_bloc.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../favorites/data/datasources/favorites_remote_datasource.dart';
import '../../../favorites/data/repositories/favorites_repository_impl.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../../profile/presentation/pages/profile_page.dart';

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

  // Yalnızca ziyaret edilen sekmeler kurulur; sonra IndexedStack içinde canlı
  // kalır (durum korunur). Açılışta tüm sekmelerin ağ isteğini birden tetiklemeyi
  // önler.
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _visited.add(_currentIndex);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex && _visited.contains(index)) return;
    setState(() {
      _visited.add(index);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Paylaşılan blocs. Home/Search/Packages blocs ilgili sayfaların kendi
    // içinde sağlanır; burada yalnız sekmeler arası paylaşılanlar var.
    return MultiBlocProvider(
      providers: [
        // Favoriler tüm sekmelerde paylaşılır; ana sayfadaki favori rozetleri için
        // açılışta (HomePage bunu okuduğunda) yüklenir.
        BlocProvider(
          create: (context) => FavoritesBloc(
            repository: FavoritesRepositoryImpl(
              remoteDataSource: FavoritesRemoteDataSource(dioClient: appDioClient),
            ),
          )..add(const LoadFavorites()),
        ),
        // Siparişler — yalnız Sipariş sekmesi açıldığında (OrdersPage.initState) yüklenir.
        BlocProvider(
          create: (context) => OrdersBloc(
            repository: OrdersRepositoryImpl(
              remoteDataSource: OrdersRemoteDataSource(dioClient: appDioClient),
            ),
          ),
        ),
        // Profil — yalnız Profil sekmesi ilk kez kurulduğunda yüklenir.
        BlocProvider(
          create: (context) => ProfileBloc(
            profileRepository: ProfileRepositoryImpl(
              remoteDataSource: ProfileRemoteDataSource(dioClient: appDioClient),
              tokenStorage: appTokenStorage,
            ),
          )..add(LoadProfile()),
        ),
      ],
      child: Scaffold(
        body: _buildBody(),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }

  Widget _buildBody() {
    // MapPage native PlatformView (Mapbox GL) kullanır ve oluşturulurken görünür
    // olmalı; bu yüzden IndexedStack'e koymuyoruz, seçilince doğrudan gösteriyoruz.
    if (_currentIndex == 2) {
      return MapPage(
        latitude: widget.latitude,
        longitude: widget.longitude,
        dioClient: appDioClient,
      );
    }

    // Görsel index → IndexedStack index (0,1 aynı; 3,4,5 → 2,3,4)
    final stackIndex = _currentIndex > 2 ? _currentIndex - 1 : _currentIndex;

    return IndexedStack(
      index: stackIndex,
      children: [
        _lazy(0, () => HomePage(latitude: widget.latitude, longitude: widget.longitude)),
        _lazy(1, () => SearchPage(latitude: widget.latitude, longitude: widget.longitude)),
        _lazy(3, () => OrdersPage(onNavigateToHome: () => _onTabSelected(0))),
        _lazy(4, () => FavoritesPage(onNavigateToHome: () => _onTabSelected(0))),
        _lazy(5, () => ProfilePage(onTabSwitch: _onTabSelected)),
      ],
    );
  }

  Widget _lazy(int navIndex, Widget Function() builder) {
    return _visited.contains(navIndex) ? builder() : const SizedBox.shrink();
  }
}
