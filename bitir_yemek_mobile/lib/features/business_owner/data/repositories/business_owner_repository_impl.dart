import '../../domain/repositories/business_owner_repository.dart';
import '../datasources/business_owner_remote_datasource.dart';
import '../models/dashboard_stats_model.dart';
import '../models/owner_business_model.dart';
import '../models/owner_order_model.dart';
import '../models/owner_package_model.dart';

class BusinessOwnerRepositoryImpl implements BusinessOwnerRepository {
  final BusinessOwnerRemoteDataSource _remoteDataSource;

  BusinessOwnerRepositoryImpl({
    required BusinessOwnerRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  /// Runs [action], letting the datasource's [BusinessOwnerException] (which
  /// already carries a Turkish, user-facing message) propagate, while wrapping
  /// any other error so the BLoC never surfaces a raw, untranslated string.
  Future<T> _guard<T>(Future<T> Function() action, String fallback) async {
    try {
      return await action();
    } on BusinessOwnerException {
      rethrow;
    } catch (e) {
      throw BusinessOwnerException(message: fallback);
    }
  }

  @override
  Future<List<OwnerBusinessModel>> getMyBusinesses() => _guard(
    () => _remoteDataSource.getMyBusinesses(),
    'İşletmeleriniz yüklenirken bir hata oluştu',
  );

  @override
  Future<DashboardStatsModel> getDashboardStats(String businessId) => _guard(
    () => _remoteDataSource.getDashboardStats(businessId),
    'Kontrol paneli yüklenirken bir hata oluştu',
  );

  @override
  Future<List<OwnerOrderModel>> getBusinessOrders(
    String businessId, {
    String? status,
    int page = 1,
    int limit = 20,
  }) => _guard(() async {
    final data = await _remoteDataSource.getBusinessOrders(
      businessId,
      status: status,
      page: page,
      limit: limit,
    );
    final List<dynamic> rawList = data['data'] as List<dynamic>? ?? [];
    return rawList
        .map((e) => OwnerOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }, 'Siparişler yüklenirken bir hata oluştu');

  @override
  Future<List<OwnerPackageModel>> getBusinessPackages(String businessId) =>
      _guard(
        () => _remoteDataSource.getBusinessPackages(businessId),
        'Paketler yüklenirken bir hata oluştu',
      );

  @override
  Future<Map<String, dynamic>> verifyOrder(
    String businessId,
    String pickupCode,
  ) => _guard(
    () => _remoteDataSource.verifyOrder(businessId, pickupCode),
    'Sipariş doğrulanırken bir hata oluştu',
  );

  @override
  Future<OwnerPackageModel> createPackage({
    required String businessId,
    required String title,
    String? description,
    required double originalPrice,
    required double discountedPrice,
    required int quantity,
    required String pickupStart,
    required String pickupEnd,
    required String pickupDate,
  }) => _guard(
    () => _remoteDataSource.createPackage(
      businessId: businessId,
      title: title,
      description: description,
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
      quantity: quantity,
      pickupStart: pickupStart,
      pickupEnd: pickupEnd,
      pickupDate: pickupDate,
    ),
    'Paket oluşturulurken bir hata oluştu',
  );

  @override
  Future<OwnerPackageModel> updatePackage(
    String packageId, {
    String? title,
    String? description,
    double? originalPrice,
    double? discountedPrice,
    int? quantity,
    String? pickupStart,
    String? pickupEnd,
    String? pickupDate,
    bool? isActive,
  }) => _guard(
    () => _remoteDataSource.updatePackage(
      packageId,
      title: title,
      description: description,
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
      quantity: quantity,
      pickupStart: pickupStart,
      pickupEnd: pickupEnd,
      pickupDate: pickupDate,
      isActive: isActive,
    ),
    'Paket güncellenirken bir hata oluştu',
  );

  @override
  Future<void> deletePackage(String packageId) => _guard(
    () => _remoteDataSource.deletePackage(packageId),
    'Paket silinirken bir hata oluştu',
  );

  @override
  Future<OwnerBusinessModel> createBusiness({
    required String name,
    String? description,
    required String address,
    required String city,
    required String district,
    required double latitude,
    required double longitude,
    String? phone,
    required int categoryId,
  }) => _guard(
    () => _remoteDataSource.createBusiness(
      name: name,
      description: description,
      address: address,
      city: city,
      district: district,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      categoryId: categoryId,
    ),
    'İşletme oluşturulurken bir hata oluştu',
  );

  @override
  Future<List<OwnerCategoryModel>> getCategories() => _guard(
    () => _remoteDataSource.getCategories(),
    'Kategoriler yüklenirken bir hata oluştu',
  );
}
