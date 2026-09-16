import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// A shared card shell that keeps warm depth and Material tap feedback together.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.warm = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Container(
      margin: margin,
      decoration: AppDepth.surface(warm: warm),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
