import '../../domain/repositories/orders_repository.dart';
import '../datasources/orders_remote_datasource.dart';
import '../models/order_model.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  final OrdersRemoteDataSource _remoteDataSource;

  OrdersRepositoryImpl({required OrdersRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<OrdersResponse> getMyOrders({int page = 1, int limit = 10}) async {
    try {
      final data = await _remoteDataSource.getMyOrders(
        page: page,
        limit: limit,
      );
      return OrdersResponse.fromJson(data);
    } on OrdersException {
      // Datasource already produces a Turkish, user-facing message.
      rethrow;
    } catch (e) {
      throw OrdersException(message: 'Siparişler yüklenirken bir hata oluştu');
    }
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    try {
      await _remoteDataSource.cancelOrder(orderId);
    } on OrdersException {
      rethrow;
    } catch (e) {
      throw OrdersException(message: 'Sipariş iptal edilirken bir hata oluştu');
    }
  }
}
