import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/features/orders/data/repositories/preview_orders_repository.dart';

void main() {
  test(
    'preview covers every order state with consistent totals and paging',
    () async {
      final repository = PreviewOrdersRepository();
      final response = await repository.getMyOrders();
      expect(response.orders.where((order) => order.isActive), hasLength(3));
      expect(response.orders.where((order) => order.isCompleted), hasLength(2));
      expect(response.orders.where((order) => order.isCancelled), hasLength(1));
      expect(response.orders.map((order) => order.status).toSet(), {
        'confirmed',
        'pending',
        'awaiting_payment',
        'picked_up',
        'cancelled',
      });
      for (final order in response.orders) {
        expect(order.finalPrice, order.totalPrice - order.discountAmount);
        expect(order.package!.business!.name, endsWith('· TEST'));
      }
      final page = await repository.getMyOrders(page: 2, limit: 2);
      expect(page.orders, response.orders.sublist(2, 4));
      expect(page.totalPages, 3);
    },
  );

  test(
    'preview cancellation survives refresh and stays within its repository',
    () async {
      final repository = PreviewOrdersRepository();
      final before = (await repository.getMyOrders()).orders.first;
      await repository.cancelOrder(before.id);
      final after = (await repository.getMyOrders()).orders.first;
      expect(after.isCancelled, isTrue);
      expect(after.finalPrice, before.finalPrice);
      expect(after.package, before.package);
      expect(
        (await PreviewOrdersRepository().getMyOrders()).orders.first.isActive,
        isTrue,
      );
      await expectLater(
        repository.cancelOrder('real-order-id'),
        throwsStateError,
      );
    },
  );
}
