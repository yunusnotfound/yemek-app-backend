import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_artwork_image.dart';

class PackagesEmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback? onClearCategory;

  const PackagesEmptyState({
    super.key,
    required this.onRefresh,
    this.onClearCategory,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = onClearCategory != null;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 44).clamp(0, double.infinity),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                decoration: BoxDecoration(
                  color: AppColors.creamTop,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppDepth.border),
                  boxShadow: AppDepth.card,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EmptyBagPhoto(),
                    const SizedBox(height: 18),
                    Text(
                      filtered
                          ? 'Bu kategoride\nşimdilik paket yok.'
                          : 'Burada küçük\nbir mola var.',
                      textAlign: TextAlign.center,
                      style: AppTypography.h2.copyWith(
                        fontSize: 28,
                        color: AppColors.ink,
                        height: 1.1,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      filtered
                          ? 'Diğer kategorilerdeki lezzetlere göz atabilir '
                                'veya biraz sonra tekrar bakabilirsin.'
                          : 'Yakınında şu an kurtarılmayı bekleyen paket yok. '
                                'Yeni lezzetler için tekrar göz at.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onClearCategory ?? onRefresh,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          filtered
                              ? Icons.grid_view_rounded
                              : Icons.refresh_rounded,
                          size: 20,
                        ),
                        label: Text(
                          filtered ? 'Tüm paketleri gör' : 'Yenile',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (filtered) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: onRefresh,
                        child: const Text('Yenile'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBagPhoto extends StatelessWidget {
  const _EmptyBagPhoto();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 158,
        width: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 148,
              height: 148,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF9EAD9), Color(0xFFEED7BE)],
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.12,
              child: const AppArtworkImage(
                'assets/images/onboarding/rescue-bag.webp',
                height: 152,
                width: 144,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 7,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.creamTop,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppDepth.border),
                  boxShadow: AppDepth.card,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryInk,
                  size: 25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
