import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../home/data/models/package_model.dart';
import '../../../home/presentation/widgets/home_catalog_cards.dart';

class MapPackagesSheet extends StatefulWidget {
  final List<PackageModel> packages;
  final int count;
  final bool isLoading;
  final ValueChanged<PackageModel> onPackageTap;

  const MapPackagesSheet({
    super.key,
    required this.packages,
    required this.count,
    required this.onPackageTap,
    this.isLoading = false,
  });

  static double headerHeight(BuildContext context) =>
      96 + (MediaQuery.textScalerOf(context).scale(17) - 17).clamp(0, 70) * 2.3;

  @override
  State<MapPackagesSheet> createState() => _MapPackagesSheetState();
}

class _MapPackagesSheetState extends State<MapPackagesSheet> {
  final _controller = DraggableScrollableController();
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(double collapsed, ScrollController scrollController) {
    if (!_controller.isAttached) return;
    FocusScope.of(context).unfocus();
    if (_expanded && scrollController.hasClients) {
      // A collapsed panel must start at the top so the next upward gesture
      // expands the sheet instead of scrolling a hidden, offset list.
      scrollController.jumpTo(0);
    }
    _controller.animateTo(
      _expanded ? collapsed : 0.58,
      duration: MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final headerHeight = MapPackagesSheet.headerHeight(context);
      final collapsed = (headerHeight / constraints.maxHeight).clamp(0.1, 0.5);
      return NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          final expanded = notification.extent > collapsed + 0.04;
          if (expanded != _expanded) setState(() => _expanded = expanded);
          return false;
        },
        child: DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: collapsed,
          minChildSize: collapsed,
          maxChildSize: 0.84,
          snap: true,
          snapSizes: const [0.58],
          builder: (context, scrollController) => DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A704B32),
                  blurRadius: 24,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Material(
              color: AppColors.background,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                side: BorderSide(color: Color(0xFFEEDFD2), width: 0.8),
              ),
              child: CustomScrollView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PanelHeader(
                      height: headerHeight,
                      child: _buildHeader(collapsed, scrollController),
                    ),
                  ),
                  if (widget.packages.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.isLoading)
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF7E5D6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.travel_explore_rounded,
                                  size: 32,
                                  color: AppColors.primaryInk,
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              widget.isLoading
                                  ? 'Paketler hazırlanıyor'
                                  : 'Burada henüz paket yok',
                              textAlign: TextAlign.center,
                              style: AppTypography.h3.copyWith(
                                fontSize: 18,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.isLoading
                                  ? 'Yakınındaki lezzetleri getiriyoruz.'
                                  : 'Aramanı veya filtrelerini değiştirerek\nyeni lezzetler keşfedebilirsin.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        20 + MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: SliverList.builder(
                        itemCount: widget.packages.length,
                        itemBuilder: (context, index) {
                          final package = widget.packages[index];
                          return Padding(
                            key: ValueKey(package.id),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: HomeProductCard(
                              package: package,
                              onTap: () => widget.onPackageTap(package),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildHeader(double collapsed, ScrollController scrollController) =>
      Material(
        color: const Color(0xFFFFF9F2),
        child: Semantics(
          button: true,
          label: _expanded ? 'Paket listesini daralt' : 'Paket listesini aç',
          child: InkWell(
            onTap: () => _toggle(collapsed, scrollController),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCC9B9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/food_box.png',
                          width: 54,
                          height: 46,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Yakınındaki paketler',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.h3.copyWith(
                                  fontSize: 17,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.count} sürpriz paket',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E6D9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: AppColors.primaryInk,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PanelHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _PanelHeader({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _PanelHeader oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}
