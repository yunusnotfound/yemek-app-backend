import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/core/di/service_locator.dart';
import 'package:bitir_yemek_mobile/features/auth/data/models/user_model.dart';
import 'package:bitir_yemek_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:bitir_yemek_mobile/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:bitir_yemek_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:bitir_yemek_mobile/features/orders/data/models/order_model.dart';
import 'package:bitir_yemek_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:bitir_yemek_mobile/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:bitir_yemek_mobile/features/orders/presentation/pages/orders_page.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/widgets/bottom_nav_bar.dart';
import 'package:bitir_yemek_mobile/features/favorites/data/models/favorite_model.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/widgets/favorite_card.dart';
import 'package:bitir_yemek_mobile/features/business_owner/data/models/owner_order_model.dart';
import 'package:bitir_yemek_mobile/features/business_owner/data/models/owner_package_model.dart';
import 'package:bitir_yemek_mobile/features/business_owner/presentation/widgets/owner_order_tile.dart';
import 'package:bitir_yemek_mobile/features/business_owner/presentation/widgets/owner_package_tile.dart';
import 'package:bitir_yemek_mobile/features/business_owner/presentation/widgets/stat_card.dart';
import 'campaign_ui_test.dart' as preview;
import 'package:bitir_yemek_mobile/features/map/presentation/widgets/business_map_card.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/bloc/favorites_bloc.dart';

final user = UserModel.fromJson({
  'id': 'preview-user',
  'name': 'Deniz Yılmaz',
  'email': 'deniz@example.com',
  'role': 'customer',
  'isEmailVerified': true,
  'createdAt': '2026-01-01T12:00:00Z',
  'updatedAt': '2026-01-01T12:00:00Z',
});
final orderJson = {
  'id': 'preview-order',
  'packageId': 'package',
  'quantity': 1,
  'totalPrice': 599.9,
  'discountAmount': 100,
  'finalPrice': 499.9,
  'pickupCode': '482196',
  'status': 'confirmed',
  'paymentStatus': 'paid',
  'createdAt': '2026-09-08T12:00:00Z',
  'package': preview.packageJson,
  'user': {'id': 'preview-user', 'name': 'Deniz Yılmaz'},
};

class ProfileFixture extends ProfileRepository {
  @override
  Future<ProfileResult> getProfile() async => ProfileResult.success(user: user);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OrdersFixture extends OrdersRepository {
  bool cancelled = false;
  @override
  Future<OrdersResponse> getMyOrders({int page = 1, int limit = 10}) async =>
      OrdersResponse(
        orders: [
          OrderModel.fromJson({
            ...orderJson,
            if (cancelled) 'status': 'cancelled',
          }),
        ],
        total: 1,
        page: 1,
        totalPages: 1,
      );
  @override
  Future<void> cancelOrder(String orderId) async {
    cancelled = true;
  }
}

Future<GlobalKey> mount(
  WidgetTester tester,
  Widget body, {
  double scale = 1,
  int tab = 0,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: body,
          bottomNavigationBar: BottomNavBar(currentIndex: tab),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    final font = FontLoader('Korolev');
    for (final weight in ['Medium', 'Bold', 'Heavy']) {
      font.addFont(rootBundle.load('assets/fonts/Korolev $weight.otf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    appDioClient.dio.interceptors.clear();
    appDioClient.dio.httpClientAdapter = preview.CampaignAdapter();
  });

  for (final scale in [1.0, 2.0]) {
    final width = scale == 1 ? 390.0 : 320.0;
    preview.visualTest(
      'Map card keeps directions, details and drag dismissal at $width / $scale',
      (tester) async {
        var closed = 0;
        var directions = 0;
        var details = 0;
        final favorites = FavoritesBloc(
          repository: preview.QuietFavoritesRepository(),
        );
        addTearDown(favorites.close);
        final key = await mount(
          tester,
          BlocProvider.value(
            value: favorites,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BusinessMapCard(
                business: preview.package.business,
                package: preview.package,
                directions: const {'distance': 1200, 'duration': 720},
                onClose: () => closed++,
                onNavigate: () => directions++,
                onViewDetails: () => details++,
              ),
            ),
          ),
          scale: scale,
          width: width,
          tab: 1,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1) await preview.shot(tester, key, 'harita-karti');
        await tester.tap(find.text('Detaylar'));
        await tester.tap(find.text('Yol Tarifi'));
        expect(details, 1);
        expect(directions, 1);
        await tester.dragFrom(
          tester.getTopLeft(find.byType(BusinessMapCard)) +
              const Offset(100, 12),
          const Offset(0, 140),
        );
        await tester.pumpAndSettle();
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      },
    );

    preview.visualTest('Profile is readable and editable at $width / $scale', (
      tester,
    ) async {
      final bloc = ProfileBloc(profileRepository: ProfileFixture())
        ..add(LoadProfile());
      addTearDown(bloc.close);
      final key = await mount(
        tester,
        BlocProvider.value(value: bloc, child: const ProfilePage()),
        scale: scale,
        width: width,
        tab: 4,
      );
      expect(tester.takeException(), isNull);
      await preview.shot(
        tester,
        key,
        scale == 1 ? 'profil' : 'profil-buyuk-yazi',
      );
      final edit = find.text('Profili Düzenle');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Ad Soyad'), findsOneWidget);
      expect(find.text('Deniz Yılmaz'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    preview.visualTest(
      'Order filters and cancellation still work at $width / $scale',
      (tester) async {
        final repository = OrdersFixture();
        final bloc = OrdersBloc(repository: repository);
        addTearDown(bloc.close);
        final key = await mount(
          tester,
          BlocProvider.value(value: bloc, child: const OrdersPage()),
          scale: scale,
          width: width,
          tab: 2,
        );
        expect(find.text('499,90 TL'), findsOneWidget);
        expect(find.text('482196'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await preview.shot(
          tester,
          key,
          scale == 1 ? 'siparisler' : 'siparisler-buyuk-yazi',
        );
        final cancel = find.text('Siparişi İptal Et');
        await tester.ensureVisible(cancel);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(repository.cancelled, isFalse);
        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();
        expect(repository.cancelled, isFalse);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        await tester.tap(find.text('İptal Et'));
        await tester.pumpAndSettle();
        expect(repository.cancelled, isTrue);
        final cancelledTab = find.text('İptal Edilen');
        await tester.ensureVisible(cancelledTab);
        await tester.tap(cancelledTab);
        await tester.pumpAndSettle();
        expect(find.text('499,90 TL'), findsOneWidget);
        expect(find.text('482196'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    preview.visualTest(
      'Favorite removal retains confirmation at $width / $scale',
      (tester) async {
        var removed = false;
        var opened = false;
        final key = await mount(
          tester,
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Favorilerim', style: AppTypography.h2),
              const SizedBox(height: 24),
              FavoriteCard(
                favorite: FavoriteModel.fromJson({
                  'id': 'favorite',
                  'business': preview.packageJson['business'],
                }),
                onTap: () => opened = true,
                onRemove: () => removed = true,
              ),
            ],
          ),
          scale: scale,
          width: width,
          tab: 3,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1) await preview.shot(tester, key, 'favoriler');
        await tester.tap(find.text('Mahalle Fırını'));
        expect(opened, isTrue);
        await tester.tap(find.byTooltip('Favorilerden kaldır'));
        await tester.pumpAndSettle();
        expect(removed, isFalse);
        await tester.tap(find.text('Kaldır'));
        await tester.pumpAndSettle();
        expect(removed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    preview.visualTest(
      'Owner cards retain package and verification actions at $width / $scale',
      (tester) async {
        var opened = false;
        var verified = false;
        final key = await mount(
          tester,
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('İşletme kartları', style: AppTypography.h2),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Bugün Sipariş',
                      value: '12',
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Bugün Kazanç',
                      value: '1.249,90 TL',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OwnerPackageTile(
                package: OwnerPackageModel.fromJson(preview.packageJson),
                onTap: () => opened = true,
              ),
              const SizedBox(height: 8),
              OwnerOrderTile(
                order: OwnerOrderModel.fromJson(orderJson),
                onVerifyTap: () => verified = true,
              ),
            ],
          ),
          scale: scale,
          width: width,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1) await preview.shot(tester, key, 'isletme-kartlari');
        final package = find.byType(OwnerPackageTile);
        await tester.ensureVisible(package);
        await tester.tap(package);
        expect(opened, isTrue);
        final verify = find.text('Kodu Doğrula');
        await tester.scrollUntilVisible(
          verify,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(verify);
        expect(verified, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
