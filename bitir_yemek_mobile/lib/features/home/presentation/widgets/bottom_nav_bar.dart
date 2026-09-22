import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

/// Full-width navigation with a continuous surface down to the home indicator.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BottomNavBar({super.key, required this.currentIndex, this.onTap});

  static const _activeColor = AppColors.primary;
  static const _inactiveIconColor = Color(0xFF8D9794);
  static const _inactiveTextColor = Color(0xFF68716E);

  static const List<_NavItem> _items = [
    _NavItem('Keşfet', Icons.explore_outlined),
    _NavItem('Ara', Icons.search_rounded),
    _NavItem('Sipariş', Icons.inventory_2_outlined),
    _NavItem('Favoriler', Icons.favorite_border_rounded),
    _NavItem('Profil', Icons.account_circle_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF9F2),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEDFD2), width: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (int i = 0; i < _items.length; i++)
                  Expanded(child: _buildItem(context, i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _items[index];
    final selected = index == currentIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(index),
        splashColor: _activeColor.withValues(alpha: 0.08),
        highlightColor: _activeColor.withValues(alpha: 0.04),
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 27,
                    color: selected ? _activeColor : _inactiveIconColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    textScaler: MediaQuery.textScalerOf(
                      context,
                    ).clamp(maxScaleFactor: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: constraints.maxWidth < 70 ? 12 : 13,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected ? _activeColor : _inactiveTextColor,
                    ),
                  ),
                ],
              ),
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
  const _NavItem(this.label, this.icon);
}
