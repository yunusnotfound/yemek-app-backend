import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

/// Harita üzerinde, arama çubuğunun altındaki yatay filtre çubuğu.
/// "Şimdi Al" toggle'ı + tekli seçimli kategori çipleri.
class MapFilterBar extends StatelessWidget {
  /// Yakındaki işletmelerden türetilen kategoriler (id + ad).
  final List<({int id, String name})> categories;

  /// Seçili kategori id'si; null = "Tümü".
  final int? selectedCategoryId;

  /// "Şimdi Al" filtresi aktif mi.
  final bool collectNow;

  final ValueChanged<int?> onCategorySelected;
  final ValueChanged<bool> onCollectNowChanged;

  static const int _tealColor = 0xFF0E5A4F;

  const MapFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.collectNow,
    required this.onCategorySelected,
    required this.onCollectNowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        children: [
          // Şimdi Al toggle
          _Pill(
            label: 'Şimdi Al',
            icon: Icons.bolt,
            selected: collectNow,
            selectedColor: const Color(_tealColor),
            onTap: () => onCollectNowChanged(!collectNow),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Ayraç
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 14),
            color: AppColors.divider,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Tümü
          _Pill(
            label: 'Tümü',
            selected: selectedCategoryId == null,
            selectedColor: AppColors.primary,
            onTap: () => onCategorySelected(null),
          ),
          // Kategoriler
          for (final c in categories) ...[
            const SizedBox(width: AppSpacing.sm),
            _Pill(
              label: c.name,
              selected: selectedCategoryId == c.id,
              selectedColor: AppColors.primary,
              onTap: () => onCategorySelected(c.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? selectedColor : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? selectedColor.withValues(alpha: 0.3)
                      : AppColors.shadow,
                  blurRadius: selected ? 8 : 2,
                  offset: Offset(0, selected ? 2 : 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
