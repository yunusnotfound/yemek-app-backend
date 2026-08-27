import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../bloc/owner_packages_bloc.dart';
import '../widgets/owner_package_tile.dart';
import 'package_form_page.dart';

class OwnerPackagesPage extends StatefulWidget {
  final String businessId;

  const OwnerPackagesPage({super.key, required this.businessId});

  @override
  State<OwnerPackagesPage> createState() => _OwnerPackagesPageState();
}

class _OwnerPackagesPageState extends State<OwnerPackagesPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<OwnerPackagesBloc>().add(
      LoadBusinessPackages(businessId: widget.businessId),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<OwnerPackagesBloc, OwnerPackagesState>(
        listener: (context, state) {
          if (state is PackageDeleteError) {
            AppNotice.error(context, state.message);
          }
        },
        buildWhen: (previous, current) =>
            current is! PackageDeleteError &&
            (previous.runtimeType != current.runtimeType ||
                current is OwnerPackagesLoaded),
        builder: (context, state) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<OwnerPackagesBloc>().add(const RefreshPackages());
              await context.read<OwnerPackagesBloc>().stream.firstWhere(
                (s) => s is OwnerPackagesLoaded || s is OwnerPackagesError,
              );
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: AppColors.background,
                  pinned: true,
                  title: const Text('Paketlerim'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => context.read<OwnerPackagesBloc>().add(
                        const RefreshPackages(),
                      ),
                    ),
                  ],
                ),
                if (state is OwnerPackagesLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (state is OwnerPackagesError)
                  SliverFillRemaining(
                    child: _ErrorView(
                      message: state.message,
                      onRetry: () => context.read<OwnerPackagesBloc>().add(
                        LoadBusinessPackages(businessId: widget.businessId),
                      ),
                    ),
                  )
                else if (state is OwnerPackagesLoaded)
                  state.packages.isEmpty
                      ? SliverFillRemaining(
                          child: _EmptyView(onAdd: () => _openCreate(context)),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(
                            AppSpacing.screenPadding,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((ctx, i) {
                              final pkg = state.packages[i];
                              return OwnerPackageTile(
                                package: pkg,
                                onTap: () => _openEdit(context, pkg.id),
                                onDelete: () => context
                                    .read<OwnerPackagesBloc>()
                                    .add(DeletePackage(packageId: pkg.id)),
                              );
                            }, childCount: state.packages.length),
                          ),
                        )
                else
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Paket'),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<OwnerPackagesBloc>(),
          child: PackageFormPage(businessId: widget.businessId),
        ),
      ),
    );
    if (result == true && context.mounted) {
      context.read<OwnerPackagesBloc>().add(const RefreshPackages());
    }
  }

  Future<void> _openEdit(BuildContext context, String packageId) async {
    final state = context.read<OwnerPackagesBloc>().state;
    if (state is! OwnerPackagesLoaded) return;
    final pkg = state.packages.firstWhere((p) => p.id == packageId);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<OwnerPackagesBloc>(),
          child: PackageFormPage(businessId: widget.businessId, package: pkg),
        ),
      ),
    );
    if (result == true && context.mounted) {
      context.read<OwnerPackagesBloc>().add(const RefreshPackages());
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Henüz paket yok', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'İlk sürpriz paketinizi oluşturun\nve israfı önleyin!',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('İlk Paketi Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
