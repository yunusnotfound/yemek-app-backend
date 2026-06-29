import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

/// TGTG tarzı, harita üzerinde yüzen arama çubuğu.
/// İsim ile client-side arama yapar; her değişiklikte [onChanged] tetiklenir.
class MapSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback? onLocationTap;
  final TextEditingController controller;

  const MapSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.search, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'İşletme ara',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
        ),
        if (onLocationTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onLocationTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.near_me_outlined,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
