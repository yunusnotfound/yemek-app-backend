import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/core/di/service_locator.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/reservation_model.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/pages/reservation_success_page.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/bottom_nav_bar.dart';
import 'package:bitir_yemek_mobile/features/main/presentation/pages/main_scaffold.dart';
import 'package:bitir_yemek_mobile/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:bitir_yemek_mobile/features/orders/presentation/pages/orders_page.dart';
import 'campaign_ui_test.dart' as preview;
import 'design_ui_test.dart' as fixtures;

class _NavigationAdapter extends preview.CampaignAdapter {
  int orderRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (options.path == '/orders') {
      orderRequests++;
      body = {
        'data': orderRequests > 1 ? [fixtures.orderJson] : [],
        'pagination': {
          'page': 1,
          'totalPages': 1,
          'total': orderRequests > 1 ? 1 : 0,
        },
      };
    } else if (options.path == '/favorites') {
      body = {'favorites': []};
    } else if (options.path == '/categories') {
      body = {'categories': []};
    } else if (options.path == '/packages') {
      body = {
        'packages': [],
        'pagination': {'page': 1, 'totalPages': 1, 'total': 0},
      };
    }
    if (body == null) return super.fetch(options, requestStream, cancelFuture);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _reservation = ReservationModel(
  id: 'preview-order',
  packageId: 'package',
  quantity: 1,
  totalPrice: 599.9,
  discountAmount: 100,
  finalPrice: 499.9,
  pickupCode: '482196',
  status: 'confirmed',
  paymentStatus: 'paid',
);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  for (final initialIndex in [2, 3]) {
    testWidgets(
      'success opens Orders and refreshes only the cached list (initial tab $initialIndex)',
      (tester) async {
        final adapter = _NavigationAdapter();
        appDioClient.dio.interceptors.clear();
        appDioClient.dio.httpClientAdapter = adapter;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.lightTheme,
            home: MainScaffold(
              latitude: 41,
              longitude: 29,
              initialIndex: initialIndex,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mainState = tester.state(find.byType(MainScaffold));
        final requestsBefore = adapter.orderRequests;
        expect(requestsBefore, initialIndex == 2 ? 1 : 0);
        if (initialIndex == 2) {
          tester.element(find.byType(OrdersPage)).read<OrdersBloc>().add(
            const ChangeOrderFilter(filter: OrderFilter.completed),
          );
          await tester.pumpAndSettle();
        }
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ReservationSuccessPage(
              reservation: _reservation,
              package: preview.package,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('499,90 TL'), findsOneWidget);
        final button = find.widgetWithText(ElevatedButton, 'Siparişlerime Git');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(ReservationSuccessPage), findsNothing);
        expect(tester.state(find.byType(MainScaffold)), same(mainState));
        expect(
          tester.widget<BottomNavBar>(find.byType(BottomNavBar)).currentIndex,
          2,
        );
        expect(adapter.orderRequests, requestsBefore + 1);
        if (initialIndex == 2) {
          expect(find.text('Günün sürpriz paketi'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'success home action returns to Keşfet while preserving main route',
    (tester) async {
      final adapter = _NavigationAdapter();
      appDioClient.dio.interceptors.clear();
      appDioClient.dio.httpClientAdapter = adapter;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.lightTheme,
          home: const MainScaffold(
            latitude: 41,
            longitude: 29,
            initialIndex: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mainState = tester.state(find.byType(MainScaffold));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ReservationSuccessPage(
            reservation: _reservation,
            package: preview.package,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, 'Ana Sayfaya Dön');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MainScaffold)), same(mainState));
      expect(
        tester.widget<BottomNavBar>(find.byType(BottomNavBar)).currentIndex,
        0,
      );
      expect(adapter.orderRequests, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
