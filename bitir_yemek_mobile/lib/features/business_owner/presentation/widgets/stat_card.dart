import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDepth.surface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: AppDepth.iconTile(color: color),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
