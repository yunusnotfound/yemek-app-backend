import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

/// Modern floating bottom navigation bar.
/// Yüzen yuvarlak bir çubuk; aktif sekmenin ikonu marka renginde bir highlight
/// pill içinde gösterilir. Arayüz (currentIndex/onTap) korunur.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BottomNavBar({super.key, required this.currentIndex, this.onTap});

  static const List<_NavItem> _items = [
    _NavItem('Keşfet', Icons.explore_outlined, Icons.explore),
    _NavItem('Ara', Icons.search_outlined, Icons.search), // MapPage (harita)
    _NavItem('Sipariş', Icons.inventory_2_outlined, Icons.inventory_2),
    _NavItem('Favoriler', Icons.favorite_outline, Icons.favorite),
    _NavItem('Profil', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: AppDepth.surface(radius: 26, elevated: true),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(child: _buildItem(context, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _items[index];
    final selected = index == currentIndex;
    final color = selected ? AppColors.primaryInk : AppColors.textHint;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap == null ? null : () => onTap!(index),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  // Keep all five labels visible; Semantics carries the full
                  // destination name independently of this compact caption.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    height: 1.0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}
