import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class OrderQuantitySelector extends StatelessWidget {
  final int quantity, maximum;
  final bool enabled;
  final ValueChanged<int> onChanged;
  const OrderQuantitySelector({
    super.key,
    required this.quantity,
    required this.maximum,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppDepth.surface(),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Paket adedi',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Adedi azalt',
          onPressed: enabled && quantity > 1
              ? () => onChanged(quantity - 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Semantics(
          liveRegion: true,
          label: '$quantity paket',
          child: Text('$quantity', style: AppTypography.h3),
        ),
        IconButton(
          tooltip: 'Adedi artır',
          onPressed: enabled && quantity < maximum
              ? () => onChanged(quantity + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );
}
