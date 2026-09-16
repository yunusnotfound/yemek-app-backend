import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/di/service_locator.dart';
import '../../home/data/models/reservation_model.dart';
import '../../home/data/models/package_model.dart';

class CouponsRepository {
  static final _changes = StreamController<void>.broadcast();
  static Stream<void> get changes => _changes.stream;
  static void invalidate() => _changes.add(null);
  final Dio dio;
  CouponsRepository({Dio? dio}) : dio = dio ?? appDioClient.dio;

  Future<CouponWallet> wallet() async {
    final data = (await dio.get('/coupons/mine')).data as Map<String, dynamic>;
    final savings = data['savings'] as Map<String, dynamic>? ?? {};
    return CouponWallet(
      coupons: (data['coupons'] as List)
          .map((c) => CouponModel.fromJson(c))
          .toList(),
      saved: double.tryParse('${savings['totalSaved']}') ?? 0,
      rescued: (savings['rescuedPackages'] as num?)?.toInt() ?? 0,
    );
  }

  Future<PackagesResponse> packages(
    String id, {
    int page = 1,
    double? latitude,
    double? longitude,
  }) async {
    final result = await dio.get(
      '/coupons/$id/packages',
      queryParameters: {
        'page': page,
        'limit': 20,
        if (latitude != null && longitude != null) ...{
          'lat': latitude,
          'lng': longitude,
          'radius': 50,
        },
      },
    );
    return PackagesResponse.fromJson(result.data);
  }

  static String error(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return e.response!.data['message']?.toString() ?? 'Kuponlar yüklenemedi';
    }
    return 'Kuponlar yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';
  }
}

class CouponWallet {
  final List<CouponModel> coupons;
  final double saved;
  final int rescued;
  const CouponWallet({
    this.coupons = const [],
    this.saved = 0,
    this.rescued = 0,
  });
  List<CouponModel> get available => coupons.where((c) => c.eligible).toList();
}
