import 'package:flutter/material.dart';

import '../../core/utils/app_artwork.dart';
import 'app_cached_image.dart';

/// A bundled preview remains visible until the disk-cached CDN image arrives.
/// Loading, timeout and offline errors never replace the preview with a spinner.
class AppArtworkImage extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  const AppArtworkImage(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final source = resolveAppArtwork(asset);
    final pixelWidth =
        (width ?? height ?? 256) * MediaQuery.devicePixelRatioOf(context);
    final preview = Image.asset(
      source.localAsset,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: pixelWidth.isFinite
          ? pixelWidth.ceil().clamp(1, source.imageUrl == null ? 1024 : 128)
          : 1024,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) =>
          fallback ?? const Center(child: Icon(Icons.image_outlined)),
    );
    return ExcludeSemantics(
      child: source.imageUrl == null
          ? preview
          : AppCachedImage(
              key: ValueKey(asset),
              imageUrl: source.imageUrl,
              width: width,
              height: height,
              fit: fit,
              loadingWidget: preview,
              placeholder: preview,
            ),
    );
  }
}
