import 'package:flutter/foundation.dart';
import '../../domain/repositories/orders_repository.dart';
import '../models/order_model.dart';

/// Opt-in design fixtures. Release builds always use the real repository.
const orderPreviewEnabled = kDebugMode && bool.fromEnvironment('ORDER_PREVIEW');

class PreviewOrdersRepository implements OrdersRepository {
  PreviewOrdersRepository({DateTime? now}) {
    final today = now ?? DateTime.now();
    _orders = [
      _sample(
        1,
        today,
        'confirmed',
        'paid',
        'Günaydın Fırın',
        'Fırından sürpriz lezzetler',
        'firin-pastane.png',
        89,
        1,
      ),
      _sample(
        2,
        today.subtract(const Duration(minutes: 35)),
        'pending',
        'paid',
        'Mola Kahve',
        'Kahve yanı tatlı paketi',
        'kafe.png',
        75,
        2,
        discount: 20,
      ),
      _sample(
        3,
        today.subtract(const Duration(hours: 1)),
        'awaiting_payment',
        'unpaid',
        'Bereket Mutfak',
        'Günün öğle yemeği',
        'restoran.png',
        120,
        1,
      ),
      _sample(
        4,
        today.subtract(const Duration(days: 1)),
        'picked_up',
        'paid',
        'Tatlı Atölyesi',
        'Pastane seçkisi',
        'pastane.png',
        95,
        1,
      ),
      _sample(
        5,
        today.subtract(const Duration(days: 3)),
        'picked_up',
        'paid',
        'Taze Manav',
        'Mevsim meyveleri kutusu',
        'manav.png',
        65,
        2,
      ),
      _sample(
        6,
        today.subtract(const Duration(days: 5)),
        'cancelled',
        'refunded',
        'Mahalle Market',
        'Kahvaltılık sürpriz kutu',
        'market.png',
        110,
        1,
      ),
    ];
  }

  late final List<OrderModel> _orders;

  @override
  Future<OrdersResponse> getMyOrders({int page = 1, int limit = 10}) async {
    if (page < 1 || limit < 1) throw ArgumentError('Invalid pagination');
    return OrdersResponse(
      orders: _orders.skip((page - 1) * limit).take(limit).toList(),
      total: _orders.length,
      page: page,
      totalPages: (_orders.length / limit).ceil(),
    );
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0 || !_orders[index].canCancel) {
      throw StateError('Test siparişi iptal edilemiyor');
    }
    final order = _orders[index];
    _orders[index] = OrderModel(
      id: order.id,
      packageId: order.packageId,
      quantity: order.quantity,
      totalPrice: order.totalPrice,
      discountAmount: order.discountAmount,
      finalPrice: order.finalPrice,
      pickupCode: order.pickupCode,
      status: 'cancelled',
      paymentStatus: order.paymentStatus,
      createdAt: order.createdAt,
      package: order.package,
    );
  }

  static OrderModel _sample(
    int number,
    DateTime date,
    String status,
    String paymentStatus,
    String business,
    String title,
    String image,
    double price,
    int quantity, {
    double discount = 0,
  }) {
    final packageId = 'preview-package-$number';
    return OrderModel(
      id: 'preview-order-$number',
      packageId: packageId,
      quantity: quantity,
      totalPrice: price * quantity,
      discountAmount: discount,
      finalPrice: price * quantity - discount,
      pickupCode: 'TEST0$number',
      status: status,
      paymentStatus: paymentStatus,
      createdAt: date,
      package: OrderPackageModel(
        id: packageId,
        title: title,
        discountedPrice: price,
        imageUrl: 'https://api.bitirgitsin.com/uploads/demo-catalog-v1/$image',
        business: OrderBusinessModel(
          id: 'preview-business-$number',
          name: '$business · TEST',
          address: 'Örnek Mahallesi, Deneme Sokak No: $number, İstanbul',
        ),
      ),
    );
  }
}
