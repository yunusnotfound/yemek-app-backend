import 'dart:async';

import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/features/orders/data/models/order_model.dart';
import 'package:bitir_yemek_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:bitir_yemek_mobile/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:bitir_yemek_mobile/features/orders/presentation/pages/orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

OrderModel order(String id, String status) => OrderModel(
  id: id,
  packageId: id,
  quantity: 1,
  totalPrice: 500,
  discountAmount: 0,
  finalPrice: 500,
  pickupCode: '123456',
  status: status,
  createdAt: DateTime(2026, 9, 8),
  package: OrderPackageModel(id: id, title: id, discountedPrice: 500),
);

class _Orders extends OrdersRepository {
  final List<List<OrderModel>> pages;
  final requests = <int>[];
  Completer<OrdersResponse>? nextPage;
  Completer<OrdersResponse>? refresh;

  _Orders(this.pages);

  OrdersResponse response(int page) => OrdersResponse(
    orders: pages[page - 1],
    total: pages.fold(0, (total, items) => total + items.length),
    page: page,
    totalPages: pages.length,
  );

  @override
  Future<OrdersResponse> getMyOrders({int page = 1, int limit = 10}) async {
    requests.add(page);
    if (page == 1 && requests.length > 1 && refresh != null) {
      return refresh!.future;
    }
    return page > 1 && nextPage != null ? nextPage!.future : response(page);
  }

  @override
  Future<void> cancelOrder(String orderId) async {}
}

Future<void> showOrders(WidgetTester tester, OrdersBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider.value(value: bloc, child: const OrdersPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('pagination waits for an in-flight checkout refresh', (
    tester,
  ) async {
    final repo = _Orders([
      [order('Eski paket', 'pending')],
      [order('İkinci sayfa', 'pending')],
    ]);
    final bloc = OrdersBloc(repository: repo);
    addTearDown(bloc.close);
    await showOrders(tester, bloc);
    repo.refresh = Completer<OrdersResponse>();
    bloc.add(const RefreshOrders());
    await tester.pump();
    bloc.add(const LoadMoreOrders());
    await tester.pump();
    expect(repo.requests, [1, 1]);
    repo.refresh!.complete(repo.response(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diğer siparişleri yükle'));
    await tester.pumpAndSettle();
    expect(repo.requests, [1, 1, 2]);
    expect(find.text('İkinci sayfa'), findsOneWidget);
  });

  testWidgets(
    'a checkout refresh cannot be overwritten by an older page request',
    (tester) async {
      final repo = _Orders([
        [order('Eski paket', 'pending')],
        [order('Eski ikinci sayfa', 'pending')],
      ])..nextPage = Completer<OrdersResponse>();
      final bloc = OrdersBloc(repository: repo);
      addTearDown(bloc.close);
      await showOrders(tester, bloc);
      await tester.tap(find.text('Diğer siparişleri yükle'));
      await tester.pump();
      repo.pages[0] = [order('Yeni sipariş', 'pending')];
      bloc.add(const RefreshOrders());
      await tester.pumpAndSettle();
      expect(find.text('Yeni sipariş'), findsOneWidget);
      repo.nextPage!.complete(repo.response(2));
      await tester.pumpAndSettle();
      expect((bloc.state as OrdersLoaded).orders.map((item) => item.id), [
        'Yeni sipariş',
      ]);
      expect(find.text('Eski ikinci sayfa'), findsNothing);
    },
  );

  testWidgets('empty history filter can reach an order on the next page', (
    tester,
  ) async {
    final repo = _Orders([
      List.generate(10, (i) => order('Aktif $i', 'pending')),
      [order('Tamamlanan paket', 'picked_up')],
    ]);
    final bloc = OrdersBloc(repository: repo);
    addTearDown(bloc.close);
    await showOrders(tester, bloc);
    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    expect(find.text('Tamamlanan siparişiniz yok'), findsNothing);
    expect(find.text('Diğer siparişleri yükle'), findsOneWidget);
    await tester.tap(find.text('Diğer siparişleri yükle'));
    await tester.pumpAndSettle();
    expect(repo.requests, [1, 2]);
    expect(find.text('Tamamlanan paket'), findsOneWidget);
    expect(find.text('Diğer siparişleri yükle'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'definitive empty text appears only after remaining pages are checked',
    (tester) async {
      final repo = _Orders([
        [order('Aktif 1', 'pending')],
        [order('Aktif 2', 'pending')],
      ]);
      final bloc = OrdersBloc(repository: repo);
      addTearDown(bloc.close);
      await showOrders(tester, bloc);
      await tester.tap(find.text('Geçmiş'));
      await tester.pumpAndSettle();
      expect(find.text('Tamamlanan siparişiniz yok'), findsNothing);
      await tester.tap(find.text('Diğer siparişleri yükle'));
      await tester.pumpAndSettle();
      expect(find.text('Tamamlanan siparişiniz yok'), findsOneWidget);
      expect(find.text('Diğer siparişleri yükle'), findsNothing);
    },
  );

  testWidgets(
    'short nonempty lists also expose the next page without scrolling',
    (tester) async {
      final repo = _Orders([
        [order('İlk paket', 'pending')],
        [order('Sonraki paket', 'pending')],
      ]);
      final bloc = OrdersBloc(repository: repo);
      addTearDown(bloc.close);
      await showOrders(tester, bloc);
      await tester.tap(find.text('Diğer siparişleri yükle'));
      await tester.pumpAndSettle();
      expect(find.text('Sonraki paket'), findsOneWidget);
      expect(repo.requests, [1, 2]);
    },
  );

  testWidgets(
    'changing a filter while a page loads keeps the latest selection',
    (tester) async {
      final repo = _Orders([
        [order('İlk paket', 'pending')],
        [order('İptal paket', 'cancelled')],
      ])..nextPage = Completer<OrdersResponse>();
      final bloc = OrdersBloc(repository: repo);
      addTearDown(bloc.close);
      await showOrders(tester, bloc);
      await tester.tap(find.text('Diğer siparişleri yükle'));
      await tester.pump();
      await tester.tap(find.text('İptal Edilen'));
      await tester.pump();
      expect(find.text('Diğer siparişleri yükle'), findsNothing);
      repo.nextPage!.complete(repo.response(2));
      await tester.pumpAndSettle();
      expect((bloc.state as OrdersLoaded).filter, OrderFilter.cancelled);
      expect(find.text('İptal paket'), findsOneWidget);
      expect(repo.requests, [1, 2]);
    },
  );
}
