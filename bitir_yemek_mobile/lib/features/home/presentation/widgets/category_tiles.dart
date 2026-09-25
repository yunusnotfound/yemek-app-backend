import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_artwork_image.dart';
import '../../data/models/category_model.dart';

/// Yerel önizlemelerle hemen açılan yatay kategori filtresi.
/// Bilinmeyen kategoriler ve "Hepsi" erişilebilir bir ikonla gösterilir.
class CategoryTiles extends StatelessWidget {
  final List<CategoryModel> categories;
  final int selectedIndex;
  final ValueChanged<int> onCategorySelected;

  const CategoryTiles({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onCategorySelected,
  });

  static const _photos = {
    'restoran',
    'firin',
    'pastane',
    'market',
    'kafe',
    'manav',
    'kasap',
    'bufe',
  };

  static String? _imageFor(String slug) {
    // Eski birleşik kategoriyi kullanan kayıtlar da fotoğrafını korur.
    final photo = slug == 'firin-pastane' ? 'firin' : slug;
    return _photos.contains(photo)
        ? 'assets/images/categories/$photo.webp'
        : null;
  }

  static IconData _iconFor(String slug) => switch (slug) {
    'all' => Icons.grid_view_rounded,
    'firin' || 'firin-pastane' => Icons.bakery_dining_rounded,
    'pastane' => Icons.cake_rounded,
    'kafe' => Icons.local_cafe_rounded,
    'manav' => Icons.eco_rounded,
    'market' => Icons.shopping_basket_rounded,
    'restoran' => Icons.restaurant_rounded,
    'kasap' => Icons.restaurant_menu_rounded,
    'bufe' => Icons.lunch_dining_rounded,
    _ => Icons.storefront_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final labelGrowth = (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
      0,
      double.infinity,
    );
    return SizedBox(
      // 84px fotoğraf korunur; büyük yazıda iki satırlık etiket alanı büyür.
      height: 132 + labelGrowth * 2.4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.xs,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryTile(
            label: category.name,
            imageAsset: _imageFor(category.slug),
            icon: _iconFor(category.slug),
            isSelected: index == selectedIndex,
            onTap: () => onCategorySelected(index),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final String? imageAsset;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.imageAsset,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  static const double _tileSize = 84;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final fallback = Icon(
      icon,
      size: 34,
      color: isSelected ? AppColors.primaryInk : AppColors.inkSoft,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: _tileSize,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: _tileSize,
                  height: _tileSize,
                  padding: const EdgeInsets.all(3),
                  decoration: AppDepth.surface(warm: imageAsset == null)
                      .copyWith(
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppDepth.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: imageAsset == null
                        ? Center(child: fallback)
                        : AppArtworkImage(
                            imageAsset!,
                            width: _tileSize,
                            height: _tileSize,
                            fit: BoxFit.cover,
                            fallback: Center(child: fallback),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    height: 1.2,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryInk
                        : AppColors.textSecondary,
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
