import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

/// Search and location controls sharing one consistent map-overlay surface.
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

  static const _surface = Color(0xFFFFF9F2);
  static const _border = Color(0xFFEEDFD2);
  static const _shadow = [
    BoxShadow(color: Color(0x18704B32), blurRadius: 12, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _border, width: 0.8),
              boxShadow: _shadow,
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    cursorColor: AppColors.primary,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      // Override every inherited form border, including focus.
                      // The enclosing surface supplies the only outline/fill.
                      filled: false,
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: 'İşletme ara',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox(width: 16)
                      : SizedBox(
                          width: 44,
                          child: IconButton(
                            tooltip: 'Aramayı temizle',
                            onPressed: () {
                              controller.clear();
                              onChanged('');
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (onLocationTap != null) ...[
          const SizedBox(width: 8),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: _border, width: 0.8),
              ),
              boxShadow: _shadow,
            ),
            child: IconButton(
              tooltip: 'Arama ayarları',
              onPressed: onLocationTap,
              icon: const Icon(Icons.settings_outlined, color: AppColors.ink),
            ),
          ),
        ],
      ],
    );
  }
}
