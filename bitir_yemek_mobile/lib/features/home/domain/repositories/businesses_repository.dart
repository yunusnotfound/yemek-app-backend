import '../../data/repositories/businesses_repository_impl.dart';

abstract class BusinessesRepository {
  Future<BusinessesResult> getNearbyBusinesses({
    required double latitude,
    required double longitude,
    double radius = 5.0,
    int page = 1,
    int limit = 10,
  });

  Future<BusinessesResult> getBusinesses({
    String? city,
    String? district,
    int page = 1,
    int limit = 10,
  });

  Future<PackagesResult> getPackages({
    String? categoryId,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
  });

  Future<PackagesResult> getNearbyPackages({
    required double latitude,
    required double longitude,
    double radius = 5.0,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
    String? categoryId,
  });

  Future<CategoriesResult> getCategories({bool forceRefresh = false});

  Future<ReservationResult> createReservation({
    required String packageId,
    int quantity = 1,
    String? couponCode,
  });

  Future<CouponResult> validateCoupon({required String code});

  Future<BusinessDetailResult> getBusinessDetail(String businessId);
}
