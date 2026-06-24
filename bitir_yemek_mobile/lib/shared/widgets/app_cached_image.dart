import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A reusable cached image widget with timeout fallback.
///
/// If the image doesn't load within [timeout], it shows the [placeholder]
/// instead of an infinite CircularProgressIndicator.
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
    if (oldWidget.imageUrl != widget.imageUrl) {
      _timer?.cancel();
      _loaded = false;
      _timedOut = false;
      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        _timer = Timer(widget.timeout, () {
          if (mounted && !_loaded) {
            setState(() => _timedOut = true);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty || _timedOut) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder,
      );
    }

    // Görseli belleğe görüntülenen boyutta çöz (tam çözünürlük yerine) — RAM/GC
    // baskısını azaltır. En boy oranı bozulmasın diye yalnız tek boyut sınırlanır.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    int? memCacheWidth;
    int? memCacheHeight;
    if (widget.width != null) {
      memCacheWidth = (widget.width! * dpr).round();
    } else if (widget.height != null) {
      memCacheHeight = (widget.height! * dpr).round();
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      useOldImageOnUrlChange: true,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 600,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 300),
      imageBuilder: (context, imageProvider) {
        _loaded = true;
        _timer?.cancel();
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: widget.fit),
          ),
        );
      },
      placeholder: (context, url) =>
          widget.loadingWidget ??
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (context, url, error) => widget.placeholder,
    );
  }
}
