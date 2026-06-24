import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../data/datasources/business_owner_remote_datasource.dart';
import '../../data/repositories/business_owner_repository_impl.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/owner_orders_bloc.dart';
import '../bloc/owner_packages_bloc.dart';
import 'business_selector_page.dart';
import 'dashboard_page.dart';
import 'owner_orders_page.dart';
import 'owner_packages_page.dart';
import 'register_business_page.dart';

/// Entry point for the business owner panel.
/// [businessId] is provided when navigating from [BusinessSelectorPage].
/// If null, this scaffold will load businesses and auto-route.
class BusinessOwnerScaffold extends StatefulWidget {
  final String? businessId;

  const BusinessOwnerScaffold({super.key, this.businessId});

  @override
  State<BusinessOwnerScaffold> createState() => _BusinessOwnerScaffoldState();
}

class _BusinessOwnerScaffoldState extends State<BusinessOwnerScaffold> {
  String? _resolvedBusinessId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.businessId != null) {
      _resolvedBusinessId = widget.businessId;
      _loading = false;
    } else {
      _loadBusinesses();
    }
  }

  Future<void> _loadBusinesses() async {
    final repo = BusinessOwnerRepositoryImpl(
      remoteDataSource: BusinessOwnerRemoteDataSource(
        dioClient: appDioClient,
      ),
    );

    try {
      final businesses = await repo.getMyBusinesses();

      if (!mounted) return;

      if (businesses.isEmpty) {
        // No businesses → go to registration
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const RegisterBusinessPage()),
        );
        if (result == true && mounted) {
          // Re-load after creation
          _loadBusinesses();
        } else if (mounted) {
          setState(() {
            _loading = false;
            _error = 'İşletme gerekli';
          });
        }
        return;
      }

      if (businesses.length == 1) {
        setState(() {
          _resolvedBusinessId = businesses[0].id;
          _loading = false;
        });
      } else {
        // Multiple businesses → selector
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BusinessSelectorPage(businesses: businesses),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: AppSpacing.md),
              Text('İşletmeler yükleniyor...', style: AppTypography.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_error != null || _resolvedBusinessId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error ?? 'İşletme bulunamadı',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadBusinesses();
                },
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return _BusinessOwnerPanel(businessId: _resolvedBusinessId!);
  }
}

class _BusinessOwnerPanel extends StatefulWidget {
  final String businessId;

  const _BusinessOwnerPanel({required this.businessId});

  @override
  State<_BusinessOwnerPanel> createState() => _BusinessOwnerPanelState();
}

class _BusinessOwnerPanelState extends State<_BusinessOwnerPanel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final repository = BusinessOwnerRepositoryImpl(
      remoteDataSource: BusinessOwnerRemoteDataSource(dioClient: appDioClient),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DashboardBloc(repository: repository)),
        BlocProvider(create: (_) => OwnerOrdersBloc(repository: repository)),
        BlocProvider(create: (_) => OwnerPackagesBloc(repository: repository)),
        BlocProvider(
          create: (_) => ProfileBloc(
            profileRepository: ProfileRepositoryImpl(
              remoteDataSource: ProfileRemoteDataSource(
                dioClient: appDioClient,
              ),
              tokenStorage: appTokenStorage,
            ),
          )..add(LoadProfile()),
        ),
      ],
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardPage(
              businessId: widget.businessId,
              onTabSwitch: (i) => setState(() => _currentIndex = i),
            ),
            OwnerOrdersPage(businessId: widget.businessId),
            OwnerPackagesPage(businessId: widget.businessId),
            const ProfilePage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
              label: 'Siparişler',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
              label: 'Paketler',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
