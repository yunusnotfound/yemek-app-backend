import '../datasources/businesses_remote_datasource.dart';
import '../models/business_model.dart';
import '../models/business_detail_model.dart';
import '../models/category_model.dart';
import '../models/package_model.dart';
import '../models/reservation_model.dart';
import '../../domain/repositories/businesses_repository.dart';
import '../../../../core/services/cache_service.dart';
import '../../../payment/data/models/payment_init_model.dart';

class BusinessesRepositoryImpl implements BusinessesRepository {
  final BusinessesRemoteDataSource _remoteDataSource;
  final CacheService _cache;

  BusinessesRepositoryImpl({
    required BusinessesRemoteDataSource remoteDataSource,
    CacheService? cacheService,
  }) : _remoteDataSource = remoteDataSource,
       _cache = cacheService ?? CacheService();

  @override
  Future<BusinessesResult> getNearbyBusinesses({
    required double latitude,
    required double longitude,
    double radius = 5.0,
    int page = 1,
    int limit = 10,
  }) async {
    final cacheKey =
        'businesses:nearby:${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}:r$radius:p$page:l$limit';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final businessesResponse = BusinessesResponse.fromJson(cached);
      return BusinessesResult.success(
        businesses: businessesResponse.data,
        pagination: businessesResponse.pagination,
      );
    }

    try {
      final response = await _remoteDataSource.getNearbyBusinesses(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        page: page,
        limit: limit,
      );

      _cache.set(cacheKey, response);
      final businessesResponse = BusinessesResponse.fromJson(response);

      return BusinessesResult.success(
        businesses: businessesResponse.data,
        pagination: businessesResponse.pagination,
      );
    } on BusinessesException catch (e) {
      return BusinessesResult.failure(e.message);
    } catch (e) {
      return BusinessesResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<BusinessesResult> getBusinesses({
    String? city,
    String? district,
    int page = 1,
    int limit = 10,
  }) async {
    final cacheKey =
        'businesses:list:${city ?? ''}:${district ?? ''}:p$page:l$limit';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final businessesResponse = BusinessesResponse.fromJson(cached);
      return BusinessesResult.success(
        businesses: businessesResponse.data,
        pagination: businessesResponse.pagination,
      );
    }

    try {
      final response = await _remoteDataSource.getBusinesses(
        city: city,
        district: district,
        page: page,
        limit: limit,
      );

      _cache.set(cacheKey, response);
      final businessesResponse = BusinessesResponse.fromJson(response);

      return BusinessesResult.success(
        businesses: businessesResponse.data,
        pagination: businessesResponse.pagination,
      );
    } on BusinessesException catch (e) {
      return BusinessesResult.failure(e.message);
    } catch (e) {
      return BusinessesResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<PackagesResult> getPackages({
    String? categoryId,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    final cacheKey = "packages:list:cat${categoryId ?? ''}:p$page:l$limit";

    final cached = forceRefresh
        ? null
        : _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final packagesResponse = PackagesResponse.fromJson(cached);
      return PackagesResult.success(
        packages: packagesResponse.data,
        pagination: packagesResponse.pagination,
      );
    }

    try {
      final response = await _remoteDataSource.getPackages(
        categoryId: categoryId,
        page: page,
        limit: limit,
      );

      _cache.set(cacheKey, response);
      final packagesResponse = PackagesResponse.fromJson(response);

      return PackagesResult.success(
        packages: packagesResponse.data,
        pagination: packagesResponse.pagination,
      );
    } on BusinessesException catch (e) {
      return PackagesResult.failure(e.message);
    } catch (e) {
      return PackagesResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<PackagesResult> getNearbyPackages({
    required double latitude,
    required double longitude,
    double radius = 5.0,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
    String? categoryId,
  }) async {
    final cacheKey =
        'packages:nearby:${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}:r$radius:c${categoryId ?? ''}:p$page:l$limit';

    final cached = forceRefresh
        ? null
        : _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final packagesResponse = PackagesResponse.fromJson(cached);
      return PackagesResult.success(
        packages: packagesResponse.data,
        pagination: packagesResponse.pagination,
      );
    }

    try {
      final response = await _remoteDataSource.getNearbyPackages(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        page: page,
        limit: limit,
        categoryId: categoryId,
      );

      _cache.set(cacheKey, response);
      final packagesResponse = PackagesResponse.fromJson(response);

      return PackagesResult.success(
        packages: packagesResponse.data,
        pagination: packagesResponse.pagination,
      );
    } on BusinessesException catch (e) {
      return PackagesResult.failure(e.message);
    } catch (e) {
      return PackagesResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<CategoriesResult> getCategories({bool forceRefresh = false}) async {
    const cacheKey = 'categories:all';

    final cached = forceRefresh
        ? null
        : _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final categoriesData = cached['categories'] ?? cached['data'];
      if (categoriesData != null) {
        final categories = (categoriesData as List<dynamic>)
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return CategoriesResult.success(categories: categories);
      }
    }

    try {
      final response = await _remoteDataSource.getCategories();

      // Backend returns 'categories' key, not 'data'
      final categoriesData = response['categories'] ?? response['data'];
      if (categoriesData == null) {
        return CategoriesResult.failure('Kategori verisi bulunamadı');
      }

      // Cache categories for a longer TTL — they change very rarely.
      _cache.set(cacheKey, response, ttl: const Duration(hours: 1));

      final categories = (categoriesData as List<dynamic>)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return CategoriesResult.success(categories: categories);
    } on BusinessesException catch (e) {
      return CategoriesResult.failure(e.message);
    } catch (e) {
      return CategoriesResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<ReservationResult> createReservation({
    required String packageId,
    int quantity = 1,
    String? couponCode,
    Map<String, dynamic>? paymentCard,
  }) async {
    try {
      final response = await _remoteDataSource.createReservation(
        packageId: packageId,
        quantity: quantity,
        couponCode: couponCode,
        paymentCard: paymentCard,
      );

      final orderData = response['order'] as Map<String, dynamic>?;
      if (orderData == null) {
        return ReservationResult.failure('Rezervasyon olusturulamadi');
      }

      // A new order has been placed — stock levels have changed, so stale
      // package cache entries must be evicted.
      _cache.invalidatePattern('packages:');

      final reservation = ReservationModel.fromJson(orderData);
      final paymentData = response['payment'] as Map<String, dynamic>?;
      final payment = paymentData != null ? PaymentInit.fromJson(paymentData) : null;
      return ReservationResult.success(
        reservation: reservation,
        message: response['message'] as String?,
        payment: payment,
      );
    } on BusinessesException catch (e) {
      return ReservationResult.failure(e.message);
    } catch (e) {
      return ReservationResult.failure('Bir hata olustu: $e');
    }
  }

  @override
  Future<CouponResult> validateCoupon({required String code}) async {
    try {
      final response = await _remoteDataSource.validateCoupon(code: code);

      final couponData = response['coupon'] as Map<String, dynamic>?;
      if (couponData == null) {
        return CouponResult.failure('Kupon dogrulanamadi');
      }

      final coupon = CouponModel.fromJson(couponData);
      return CouponResult.success(coupon: coupon);
    } on BusinessesException catch (e) {
      return CouponResult.failure(e.message);
    } catch (e) {
      return CouponResult.failure('Bir hata olustu: $e');
    }
  }

  @override
  Future<BusinessDetailResult> getBusinessDetail(String businessId) async {
    try {
      final response = await _remoteDataSource.getBusinessDetail(businessId);
      final businessData = response['business'] as Map<String, dynamic>?;
      if (businessData == null) {
        return BusinessDetailResult.failure('Isletme bilgisi bulunamadi');
      }

      final detail = BusinessDetailModel.fromJson(businessData);
      return BusinessDetailResult.success(detail: detail);
    } on BusinessesException catch (e) {
      return BusinessDetailResult.failure(e.message);
    } catch (e) {
      return BusinessDetailResult.failure('Bir hata olustu: $e');
    }
  }
}

class ReservationResult {
  final bool isSuccess;
  final ReservationModel? reservation;
  final PaymentInit? payment;
  final String? message;
  final String? error;

  ReservationResult._({
    required this.isSuccess,
    this.reservation,
    this.payment,
    this.message,
    this.error,
  });

  factory ReservationResult.success({
    required ReservationModel reservation,
    PaymentInit? payment,
    String? message,
  }) {
    return ReservationResult._(
      isSuccess: true,
      reservation: reservation,
      payment: payment,
      message: message,
    );
  }

  factory ReservationResult.failure(String error) {
    return ReservationResult._(isSuccess: false, error: error);
  }
}

class CouponResult {
  final bool isSuccess;
  final CouponModel? coupon;
  final String? error;

  CouponResult._({required this.isSuccess, this.coupon, this.error});

  factory CouponResult.success({required CouponModel coupon}) {
    return CouponResult._(isSuccess: true, coupon: coupon);
  }

  factory CouponResult.failure(String error) {
    return CouponResult._(isSuccess: false, error: error);
  }
}

class CategoriesResult {
  final bool isSuccess;
  final List<CategoryModel>? categories;
  final String? error;

  CategoriesResult._({required this.isSuccess, this.categories, this.error});

  factory CategoriesResult.success({required List<CategoryModel> categories}) {
    return CategoriesResult._(isSuccess: true, categories: categories);
  }

  factory CategoriesResult.failure(String error) {
    return CategoriesResult._(isSuccess: false, error: error);
  }
}

class PackagesResult {
  final bool isSuccess;
  final List<PackageModel>? packages;
  final PaginationModel? pagination;
  final String? error;

  PackagesResult._({
    required this.isSuccess,
    this.packages,
    this.pagination,
    this.error,
  });

  factory PackagesResult.success({
    required List<PackageModel> packages,
    required PaginationModel pagination,
  }) {
    return PackagesResult._(
      isSuccess: true,
      packages: packages,
      pagination: pagination,
    );
  }

  factory PackagesResult.failure(String error) {
    return PackagesResult._(isSuccess: false, error: error);
  }
}

class BusinessesResult {
  final bool isSuccess;
  final List<BusinessModel>? businesses;
  final PaginationModel? pagination;
  final String? error;

  BusinessesResult._({
    required this.isSuccess,
    this.businesses,
    this.pagination,
    this.error,
  });

  factory BusinessesResult.success({
    required List<BusinessModel> businesses,
    required PaginationModel pagination,
  }) {
    return BusinessesResult._(
      isSuccess: true,
      businesses: businesses,
      pagination: pagination,
    );
  }

  factory BusinessesResult.failure(String error) {
    return BusinessesResult._(isSuccess: false, error: error);
  }
}

class BusinessDetailResult {
  final bool isSuccess;
  final BusinessDetailModel? detail;
  final String? error;

  BusinessDetailResult._({required this.isSuccess, this.detail, this.error});

  factory BusinessDetailResult.success({required BusinessDetailModel detail}) {
    return BusinessDetailResult._(isSuccess: true, detail: detail);
  }

  factory BusinessDetailResult.failure(String error) {
    return BusinessDetailResult._(isSuccess: false, error: error);
  }
}
