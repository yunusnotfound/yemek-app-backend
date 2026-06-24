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
    _NavItem('Ara', Icons.search_outlined, Icons.search),
    _NavItem('Harita', Icons.map_outlined, Icons.map),
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(child: _buildItem(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    final selected = index == currentIndex;
    final color = selected ? AppColors.primary : AppColors.textHint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap?.call(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}
