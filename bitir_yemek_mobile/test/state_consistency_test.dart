import 'dart:async';
import 'package:bitir_yemek_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:bitir_yemek_mobile/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:bitir_yemek_mobile/features/business_owner/data/models/owner_package_model.dart';
import 'package:bitir_yemek_mobile/features/business_owner/presentation/bloc/owner_packages_bloc.dart'
    as owner_packages;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/pages/all_packages_page.dart';
import 'package:bitir_yemek_mobile/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:bitir_yemek_mobile/features/favorites/data/models/favorite_model.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:bitir_yemek_mobile/features/cards/domain/repositories/cards_repository.dart';
import 'package:bitir_yemek_mobile/features/cards/data/models/saved_card_model.dart';
import 'package:bitir_yemek_mobile/features/cards/presentation/bloc/cards_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/domain/repositories/businesses_repository.dart';
import 'package:bitir_yemek_mobile/features/home/data/repositories/businesses_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/package_model.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/packages_bloc.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/reservation_bloc.dart';
import 'package:bitir_yemek_mobile/features/business_owner/domain/repositories/business_owner_repository.dart';
import 'package:bitir_yemek_mobile/features/business_owner/data/models/owner_order_model.dart';
import 'package:bitir_yemek_mobile/features/business_owner/data/models/dashboard_stats_model.dart';
import 'package:bitir_yemek_mobile/features/business_owner/presentation/bloc/owner_orders_bloc.dart'
    as owner;
import 'package:bitir_yemek_mobile/features/business_owner/presentation/bloc/dashboard_bloc.dart';
import 'package:bitir_yemek_mobile/features/payment/domain/repositories/payment_repository.dart';
import 'package:bitir_yemek_mobile/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/payment/presentation/bloc/payment_bloc.dart';

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class FavoritesFake implements FavoritesRepository {
  final adding = Completer<void>();
  bool present = false;
  int removes = 0;
  @override
  Future<void> addFavorite(String businessId) async {
    await adding.future;
    present = true;
  }

  @override
  Future<void> removeFavorite(String businessId) async {
    removes++;
    present = false;
  }

  @override
  Future<FavoritesResponse> getFavorites({
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
  }) async => FavoritesResponse(
    favorites: present
        ? [
            FavoriteModel(
              id: 'fav',
              businessId: 'business',
              businessName: 'Test',
              address: '',
              city: '',
              district: '',
              rating: 0,
              createdAt: DateTime(2026),
            ),
          ]
        : [],
    total: present ? 1 : 0,
    page: 1,
    totalPages: 1,
  );
  @override
  Future<bool> checkFavorite(String businessId) async => present;
}

class CardsFake implements CardsRepository {
  final deletingA = Completer<void>();
  final server = <SavedCardModel>[
    const SavedCardModel(cardToken: 'A'),
    const SavedCardModel(cardToken: 'B'),
  ];
  @override
  Future<List<SavedCardModel>> getCards() async => List.of(server);
  @override
  Future<void> deleteCard(String token) async {
    if (token == 'A') await deletingA.future;
    server.removeWhere((card) => card.cardToken == token);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final package = PackageModel.fromJson({
  'id': 'package',
  'title': 'Test',
  'pickupDate': '2099-01-01',
  'pickupStart': '12:00',
  'pickupEnd': '23:00',
  'business': {
    'id': 'business',
    'name': 'Test',
    'category': {'id': 1, 'name': 'Test', 'slug': 'test'},
  },
});
PackagesResult page(int number) => PackagesResult.success(
  packages: [package],
  pagination: PaginationModel(total: 2, page: number, limit: 1, totalPages: 2),
);

class CatalogFake implements BusinessesRepository {
  bool fail = false;
  final pages = <int>[];
  final reserving = Completer<ReservationResult>();
  final validating = Completer<CouponResult>();
  int reservations = 0;
  @override
  Future<PackagesResult> getNearbyPackages({
    required double latitude,
    required double longitude,
    double radius = 5,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
    String? categoryId,
  }) async {
    pages.add(page);
    return fail
        ? PackagesResult.failure('offline')
        : (page == 1 ? _first : _second);
  }

  final _first = page(1);
  final _second = page(2);
  @override
  Future<ReservationResult> createReservation({
    required String packageId,
    int quantity = 1,
    String? couponCode,
    Map<String, dynamic>? paymentCard,
    double? expectedFinalPrice,
  }) {
    reservations++;
    return reserving.future;
  }

  @override
  Future<CouponResult> validateCoupon({
    required String code,
    String? packageId,
    double? orderAmount,
    int quantity = 1,
  }) => validating.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CatalogListFake extends CatalogFake {
  @override
  Future<PackagesResult> getNearbyPackages({
    required double latitude,
    required double longitude,
    double radius = 5,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
    String? categoryId,
  }) async {
    pages.add(page);
    return PackagesResult.success(
      packages: List.generate(page == 1 ? 10 : 4, (i) {
        final number = (page - 1) * 10 + i + 1;
        return PackageModel.fromJson({
          'id': 'package-$number',
          'title': 'Paket $number',
          'pickupDate': '2099-01-01',
          'pickupStart': '12:00',
          'pickupEnd': '23:00',
          'business': {
            'id': 'business-$number',
            'name': 'İşletme $number',
            'category': {'id': 1, 'name': 'Test', 'slug': 'test'},
          },
        });
      }),
      pagination: PaginationModel(
        total: 14,
        page: page,
        limit: 10,
        totalPages: 2,
      ),
    );
  }
}

class OwnerFake implements BusinessOwnerRepository {
  final oldPackages = Completer<List<OwnerPackageModel>>();
  @override
  Future<List<OwnerPackageModel>> getBusinessPackages(String businessId) =>
      businessId == 'old' ? oldPackages.future : Future.value([]);
  final oldOrders = Completer<List<OwnerOrderModel>>();
  final oldDashboard = Completer<DashboardStatsModel>();
  @override
  Future<List<OwnerOrderModel>> getBusinessOrders(
    String businessId, {
    String? status,
    int page = 1,
    int limit = 20,
  }) => status == 'pending' ? oldOrders.future : Future.value([]);
  @override
  Future<DashboardStatsModel> getDashboardStats(String businessId) =>
      businessId == 'old' ? oldDashboard.future : Future.value(stats(2));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DashboardStatsModel stats(int count) => DashboardStatsModel.fromJson({
  'stats': {'totalPackages': count},
});

class PaymentFake implements PaymentRepository {
  int calls = 0;
  @override
  Future<PaymentStatusResult> getStatus(String id, {bool sync = false}) async {
    calls++;
    return PaymentStatusResult.failure('offline');
  }
}

class ProfileFake implements ProfileRepository {
  final loading = Completer<ProfileResult>();
  int loads = 0;
  @override
  Future<ProfileResult> getProfile() {
    loads++;
    return loading.future;
  }

  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('all packages scrolls and loads the remaining page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = CatalogListFake();
    final packages = PackagesBloc(repository: repository)
      ..add(const LoadNearbyPackages(latitude: 41, longitude: 29));
    final favorites = FavoritesBloc(repository: FavoritesFake());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: packages),
            BlocProvider.value(value: favorites),
          ],
          child: const AllPackagesView(
            title: 'Test',
            latitude: 41,
            longitude: 29,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -2200), 2500);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Paket 14'), 350, maxScrolls: 20);
    await tester.pumpAndSettle();
    expect(repository.pages, [1, 2]);
    expect((packages.state as PackagesLoaded).packages, hasLength(14));
    expect(find.text('Paket 14'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await packages.close();
      await favorites.close();
    });
  });

  test('late profile response cannot restore a logged-out session', () async {
    final repository = ProfileFake();
    final bloc = ProfileBloc(profileRepository: repository)..add(LoadProfile());
    await flush();
    bloc.add(ProfileLogoutRequested());
    await flush();
    repository.loading.complete(ProfileResult.failure('late response'));
    await flush();
    expect(bloc.state, isA<ProfileLoggedOut>());
    bloc.add(LoadProfile());
    await flush();
    expect(repository.loads, 1);
    await bloc.close();
  });

  test(
    'a previous business package failure cannot replace the new business list',
    () async {
      final repository = OwnerFake();
      final bloc = owner_packages.OwnerPackagesBloc(repository: repository);
      bloc.add(const owner_packages.LoadBusinessPackages(businessId: 'old'));
      await flush();
      bloc.add(const owner_packages.LoadBusinessPackages(businessId: 'new'));
      await flush();
      repository.oldPackages.completeError(StateError('old business failed'));
      await flush();
      expect(bloc.state, isA<owner_packages.OwnerPackagesLoaded>());
      await bloc.close();
    },
  );

  test(
    'rapid favorite add/remove ends in the user last requested state',
    () async {
      final repository = FavoritesFake();
      final bloc = FavoritesBloc(repository: repository);
      bloc.add(const LoadFavorites());
      await flush();
      bloc.add(const ToggleFavorite(businessId: 'business'));
      await flush();
      bloc.add(const ToggleFavorite(businessId: 'business'));
      await flush();
      repository.adding.complete();
      await flush();
      expect(repository.present, isFalse);
      expect(repository.removes, 1);
      expect(bloc.isFavorite('business'), isFalse);
      await bloc.close();
    },
  );

  test(
    'failed card deletion never restores another successfully deleted card',
    () async {
      final repository = CardsFake();
      final bloc = CardsBloc(repository: repository)..add(const LoadCards());
      await flush();
      bloc.add(const DeleteCard(cardToken: 'A'));
      await flush();
      bloc.add(const DeleteCard(cardToken: 'B'));
      await flush();
      repository.deletingA.completeError(StateError('offline'));
      await flush();
      expect((bloc.state as CardsLoaded).cards.map((c) => c.cardToken), ['A']);
      expect(repository.server.map((c) => c.cardToken), ['A']);
      await bloc.close();
    },
  );

  test(
    'failed refresh preserves data and failed pagination can retry the same page',
    () async {
      final repository = CatalogFake();
      final bloc = PackagesBloc(repository: repository)
        ..add(const LoadNearbyPackages(latitude: 41, longitude: 29));
      await flush();
      repository.fail = true;
      bloc.add(const RefreshPackages(latitude: 41, longitude: 29));
      await flush();
      expect(bloc.state, isA<PackagesLoaded>());
      expect((bloc.state as PackagesLoaded).packages.single.id, 'package');
      bloc.add(const LoadMorePackages(latitude: 41, longitude: 29));
      await flush();
      expect(bloc.state, isA<PackagesLoaded>());
      repository.fail = false;
      bloc.add(const LoadMorePackages(latitude: 41, longitude: 29));
      await flush();
      expect(repository.pages, [1, 1, 2, 2]);
      expect((bloc.state as PackagesLoaded).pagination.page, 2);
      await bloc.close();
    },
  );

  test(
    'late owner order and dashboard responses cannot replace the new selection',
    () async {
      final repository = OwnerFake();
      final orders = owner.OwnerOrdersBloc(repository: repository);
      final dashboard = DashboardBloc(repository: repository);
      orders.add(
        const owner.LoadBusinessOrders(
          businessId: 'business',
          status: 'pending',
        ),
      );
      dashboard.add(const LoadDashboard(businessId: 'old'));
      await flush();
      orders.add(
        const owner.LoadBusinessOrders(
          businessId: 'business',
          status: 'confirmed',
        ),
      );
      dashboard.add(const LoadDashboard(businessId: 'new'));
      await flush();
      repository.oldOrders.complete([]);
      repository.oldDashboard.complete(stats(1));
      await flush();
      expect((orders.state as owner.OwnerOrdersLoaded).status, 'confirmed');
      expect((dashboard.state as DashboardLoaded).stats.totalPackages, 2);
      await orders.close();
      await dashboard.close();
    },
  );

  test(
    'coupon removal ignores delayed validation and repeated checkout creates one request',
    () async {
      final repository = CatalogFake();
      final bloc = ReservationBloc(repository: repository);
      bloc.add(const ValidateCoupon(code: 'TEST', orderTotal: 100));
      await flush();
      bloc.add(const ClearCoupon());
      await flush();
      repository.validating.complete(CouponResult.failure('expired'));
      await flush();
      expect(bloc.state, isA<ReservationInitial>());
      bloc.add(const CreateReservation(packageId: 'package'));
      bloc.add(const CreateReservation(packageId: 'package'));
      await flush();
      expect(repository.reservations, 1);
      repository.reserving.complete(ReservationResult.failure('test'));
      await flush();
      await bloc.close();
    },
  );

  test(
    'closing payment cancels pending verification before another network request',
    () async {
      final repository = PaymentFake();
      final bloc = PaymentBloc(repository: repository, conversationId: 'test');
      bloc.add(const PaymentVerificationRequested());
      await flush();
      await bloc.close().timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(repository.calls, 0);
    },
  );
}
