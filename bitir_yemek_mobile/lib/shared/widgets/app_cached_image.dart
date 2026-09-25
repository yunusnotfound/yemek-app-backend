import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/utils/cached_image_provider.dart';

/// A disk-cached image decoded at its displayed size.
///
/// After [timeout], the loading indicator becomes [placeholder]. The download
/// stays subscribed so a slow connection can still deliver the image later.
class AppCachedImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;
  final Widget? loadingWidget;
  final Duration timeout;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.placeholder,
    this.loadingWidget,
    this.timeout = const Duration(seconds: 15),
  });

  @override
  State<AppCachedImage> createState() => _AppCachedImageState();
}

class _AppCachedImageState extends State<AppCachedImage> {
  bool _timedOut = false;
  bool _loaded = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _timer = Timer(widget.timeout, () {
        if (mounted && !_loaded) {
          setState(() => _timedOut = true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(AppCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.timeout != widget.timeout) {
      _timer?.cancel();
      _loaded = false;
      _timedOut = false;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          // Most callers size a parent rather than this widget. Use those
          // constraints too, keeping a single decode dimension to preserve
          // the source aspect ratio. Never round an infinite layout extent.
          final width = _finiteExtent(widget.width, constraints.maxWidth);
          final height = _finiteExtent(widget.height, constraints.maxHeight);
          final cacheWidth = width == null
              ? null
              : (width * dpr).ceil().clamp(1, 2048);
          final cacheHeight = cacheWidth != null || height == null
              ? null
              : (height * dpr).ceil().clamp(1, 2048);
          return Image(
            // Keep the compressed response in the shared disk cache. Resizing
            // the disk file first decodes the full image and re-encodes a PNG
            // before anything can be displayed. Resize only at decode time.
            image: cachedImageProvider(
              widget.imageUrl!,
              pixelWidth: width == null ? null : width * dpr,
              cacheWidth: cacheWidth ?? (cacheHeight == null ? 1024 : null),
              cacheHeight: cacheHeight,
            ),
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            frameBuilder: (context, child, frame, synchronouslyLoaded) {
              if (frame != null || synchronouslyLoaded) {
                _loaded = true;
                _timer?.cancel();
                return child;
              }
              if (_timedOut) return widget.placeholder;
              return widget.loadingWidget ??
                  ColoredBox(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
            },
            errorBuilder: (context, error, stackTrace) {
              _timer?.cancel();
              return widget.placeholder;
            },
          );
        },
      ),
    );
  }

  double? _finiteExtent(double? explicit, double constrained) {
    if (explicit != null && explicit.isFinite && explicit > 0) return explicit;
    return constrained.isFinite && constrained > 0 ? constrained : null;
  }
}
