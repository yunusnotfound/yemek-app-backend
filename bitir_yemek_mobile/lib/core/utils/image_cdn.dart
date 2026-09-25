/// Optimize public production uploads with a small, reusable set of variants.
///
/// Query strings, credentials, other origins and already transformed URLs keep
/// their original request semantics. The same-zone redirect lets Cloudflare
/// serve the original when the free transformation allowance is exhausted.
String imageCdnUrl(String url, {double? pixelWidth}) {
  final source = Uri.tryParse(url);
  if (source == null ||
      source.scheme != 'https' ||
      source.host != 'api.bitirgitsin.com' ||
      source.port != 443 ||
      source.userInfo.isNotEmpty ||
      source.hasQuery ||
      source.hasFragment ||
      !source.path.startsWith('/uploads/') ||
      source.path.length == '/uploads/'.length) {
    return url;
  }

  // Limit each original to four transformation/cache variants, regardless of
  // device density or layout. Unknown sizes use the usual full-width photo.
  final requested = pixelWidth != null && pixelWidth.isFinite && pixelWidth > 0
      ? pixelWidth
      : 960.0;
  final width = const [
    320,
    640,
    960,
    1280,
  ].firstWhere((width) => width >= requested, orElse: () => 1280);
  // App artwork includes transparent cutouts layered over the onboarding UI.
  final background = source.path.startsWith('/uploads/app-artwork-v1/')
      ? 'background=transparent,'
      : '';
  return source
      .replace(
        path:
            '/cdn-cgi/image/width=$width,fit=scale-down,format=webp,'
            'quality=85,${background}onerror=redirect${source.path}',
      )
      .toString();
}
