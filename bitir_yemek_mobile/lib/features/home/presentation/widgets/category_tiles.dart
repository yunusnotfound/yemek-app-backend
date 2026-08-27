import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../data/models/category_model.dart';

/// Keşfet sayfasının üstündeki kategori şeridi.
///
/// Kutucuk düzeni: kare bir görsel alanı, altında adı. Yatay kaydırılır.
///
/// GÖRSELLER: Kategori görselleri yerel varlık olarak tutulur ve slug'a göre
/// eşlenir ([_imageFor]). `Category` modelinde `imageUrl` alanı olmadığı için
/// eşleme uygulamada yapılıyor — panelden YENİ bir kategori eklenirse görseli
/// olmayacağı için ikona düşer ([_iconFor]), ekran boş kutucuk göstermez.
/// Kalıcı çözüm backend'e `Category.imageUrl` eklemektir; düzen aynı kalır.
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

  /// Kategori slug'ına göre yerel görsel. Eşleşme yoksa null döner ve kutucuk
  /// ikona düşer.
  static String? _imageFor(String slug) {
    const base = 'assets/images/categories';
    switch (slug) {
      case 'firin-pastane':
        return '$base/firin-pastane.png';
      case 'kafe':
        return '$base/kafe.png';
      case 'manav':
        return '$base/manav.png';
      case 'market':
        return '$base/market.png';
      case 'restoran':
        return '$base/restoran.png';
      default:
        // 'all' dahil: "Hepsi" kutucuğu bilerek ikon kalır, bir kategori değil.
        return null;
    }
  }

  /// Kategori slug'ına göre ikon. Bilinmeyen slug güvenli bir varsayılana düşer,
  /// böylece panelden yeni kategori eklenince ekran boş kutucuk göstermez.
  static IconData _iconFor(String slug) {
    switch (slug) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'firin-pastane':
        return Icons.bakery_dining_rounded;
      case 'kafe':
        return Icons.local_cafe_rounded;
      case 'manav':
        return Icons.eco_rounded;
      case 'market':
        return Icons.shopping_basket_rounded;
      case 'restoran':
        return Icons.restaurant_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }

  /// Kutucuk ikonunun rengi — şerit tek renk olmasın, kategoriler ayrışsın.
  static Color _colorFor(String slug) {
    switch (slug) {
      case 'all':
        return AppColors.textSecondary;
      case 'firin-pastane':
        return const Color(0xFFD98E3E);
      case 'kafe':
        return const Color(0xFF8D6E63);
      case 'manav':
        return const Color(0xFF4CAF50);
      case 'market':
        return const Color(0xFF00897B);
      case 'restoran':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Kutucuk (84) + boşluk (8) + iki satırlık etiket payı.
      height: 132,
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
            color: _colorFor(category.slug),
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

  /// Varsa kutucuğa çizilecek görsel; null ise [icon] kullanılır.
  final String? imageAsset;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.imageAsset,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  static const double _tileSize = 84;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _tileSize,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: _tileSize,
                height: _tileSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.10)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? color.withValues(alpha: 0.16)
                          : AppColors.shadow,
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Görsel varsa onu, yoksa ikonu çiz.
                //
                // BoxFit.contain + iç boşluk: bu görseller beyaz/şeffaf zemin
                // üzerinde duran nesneler (dükkân cepheleri). `cover` kullanmak
                // kenarlarını kırpar ve dükkânın yarısı görünmez; `contain`
                // tamamını kutucuğa sığdırır. Padding, görselin köşe
                // yuvarlamasına dayanmasını önler.
                child: imageAsset == null
                    ? Icon(icon, size: 34, color: color)
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          imageAsset!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          // Varlık bulunamazsa kutucuk boş kalmasın.
                          errorBuilder: (_, _, _) =>
                              Icon(icon, size: 34, color: color),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // İki satıra izin verilir ("Fırın & Pastane" gibi uzun adlar
              // kesilmesin); yükseklik sabit olduğu için şerit zıplamaz.
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  height: 1.2,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
