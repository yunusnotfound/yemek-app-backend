part of 'packages_bloc.dart';

abstract class PackagesEvent extends Equatable {
  const PackagesEvent();

  @override
  List<Object?> get props => [];
}

class LoadNearbyPackages extends PackagesEvent {
  final double latitude;
  final double longitude;
  final double radius;

  const LoadNearbyPackages({
    required this.latitude,
    required this.longitude,
    this.radius = 5.0,
  });

  @override
  List<Object?> get props => [latitude, longitude, radius];
}

class LoadPackagesByCategory extends PackagesEvent {
  final String categoryId;
  final double latitude;
  final double longitude;

  const LoadPackagesByCategory({
    required this.categoryId,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [categoryId, latitude, longitude];
}

/// Pull-to-refresh / "Yenile": cache'i bypass ederek taze veri çeker.
/// Mevcut dolu liste korunur (shimmer'a düşmez); kategori filtresi yakındaki
/// paketlere uygulanır. [onDone] verilirse, işlem bitince (başarı/hata)
/// tamamlanır — RefreshIndicator'ın spinner'ı bunu bekler. Bu, taze veri
/// öncekiyle birebir aynı olsa bile (bloc'un yinelenen state'i bastırdığı
/// durumda) spinner'ın takılmamasını garanti eder.
class RefreshPackages extends PackagesEvent {
  final double latitude;
  final double longitude;
  final String? categoryId;
  final double radius;
  final Completer<void>? onDone;

  const RefreshPackages({
    required this.latitude,
    required this.longitude,
    this.categoryId,
    this.radius = 5.0,
    this.onDone,
  });

  // onDone eşitliğe dahil edilmez (yalnız sorgu parametreleri).
  @override
  List<Object?> get props => [latitude, longitude, categoryId, radius];
}

class LoadMorePackages extends PackagesEvent {
  final double latitude;
  final double longitude;
  final double radius;

  const LoadMorePackages({
    required this.latitude,
    required this.longitude,
    this.radius = 5.0,
  });

  @override
  List<Object?> get props => [latitude, longitude, radius];
}
