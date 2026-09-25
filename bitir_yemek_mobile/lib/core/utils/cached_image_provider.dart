import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

import 'image_cdn.dart';

/// Widgets and canvas artwork share both the CDN variants and disk cache.
/// Resize at decode time, keeping the compressed network response on disk.
ImageProvider cachedImageProvider(
  String url, {
  double? pixelWidth,
  int? cacheWidth,
  int? cacheHeight,
}) {
  final imageUrl = imageCdnUrl(url, pixelWidth: pixelWidth);
  return ResizeImage.resizeIfNeeded(
    cacheWidth,
    cacheHeight,
    CachedNetworkImageProvider(
      imageUrl,
      headers: imageUrl == url
          ? null
          : const {'Accept': 'image/webp,image/jpeg,image/png;q=0.8'},
    ),
  );
}
