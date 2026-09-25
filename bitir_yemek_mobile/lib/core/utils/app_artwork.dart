/// Only these versioned illustrations live on the CDN. All other assets keep
/// their local loading behavior, including the small logo and food-box icon.
const _remoteArtwork = {
  'categories/bufe.webp',
  'categories/firin.webp',
  'categories/kafe.webp',
  'categories/kasap.webp',
  'categories/manav.webp',
  'categories/market.webp',
  'categories/pastane.webp',
  'categories/restoran.webp',
  'onboarding/foodbox-bakery.webp',
  'onboarding/foodbox-dessert.webp',
  'onboarding/foodbox-meal.webp',
  'onboarding/kraft-texture.webp',
  'onboarding/rescue-bag.webp',
  'onboarding/waste-bin.webp',
};

class AppArtworkSource {
  final String localAsset;
  final String? imageUrl;

  const AppArtworkSource({required this.localAsset, this.imageUrl});
}

AppArtworkSource resolveAppArtwork(String asset) {
  const prefix = 'assets/images/';
  if (asset.startsWith(prefix)) {
    final relative = asset.substring(prefix.length);
    if (_remoteArtwork.contains(relative)) {
      return AppArtworkSource(
        localAsset: 'assets/previews/$relative',
        imageUrl:
            'https://api.bitirgitsin.com/uploads/app-artwork-v1/$relative',
      );
    }
  }
  return AppArtworkSource(localAsset: asset);
}
