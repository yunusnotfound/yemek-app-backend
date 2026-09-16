import 'dart:async';

import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/package_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/repositories/businesses_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/home/domain/repositories/businesses_repository.dart';
import 'package:bitir_yemek_mobile/features/home/presentation/bloc/packages_bloc.dart';
import 'package:bitir_yemek_mobile/features/main/presentation/catalog_refresh.dart';
import 'package:bitir_yemek_mobile/features/map/data/repositories/map_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/map/domain/repositories/map_repository.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_bloc.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_event.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final _package = PackageModel.fromJson({
  'id': 'package',
  'businessId': 'business',
  'title': 'Paket',
  'pickupDate': '2099-01-01',
  'pickupStart': '18:00',
  'pickupEnd': '20:00',
  'business': {
    'id': 'business',
    'name': 'İşletme',
    'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin'},
  },
});

PackagesResult _packages(List<PackageModel> packages) => PackagesResult.success(
  packages: packages,
  pagination: PaginationModel(
    total: packages.length,
    page: 1,
    limit: 10,
    totalPages: packages.isEmpty ? 0 : 1,
  ),
);

class _PackagesRepository implements BusinessesRepository {
  final queries = <({double lat, double lng, String? category, bool fresh})>[];
  Future<PackagesResult> Function()? response;

  @override
  Future<PackagesResult> getNearbyPackages({
    required double latitude,
    required double longitude,
    double radius = 5,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
    String? categoryId,
  }) {
    queries.add((
      lat: latitude,
      lng: longitude,
      category: categoryId,
      fresh: forceRefresh,
    ));
    return response?.call() ?? Future.value(_packages([_package]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MapRepository implements MapRepository {
  final queries = <({double lat, double lng, double radius})>[];
  Future<MapBusinessesResult> Function()? response;
  final business = BusinessModel.fromJson({
    'id': 'business',
    'name': 'İşletme',
    'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin'},
  });

  @override
  Future<MapBusinessesResult> getBusinessesForMap({
    required double lat,
    required double lng,
    double radius = 10,
  }) {
    queries.add((lat: lat, lng: lng, radius: radius));
    return response?.call() ??
        Future.value(MapBusinessesResult.success(businesses: [business]));
  }

  @override
  Future<BusinessPackagesResult> getNearbyPackages({
    required double lat,
    required double lng,
    double radius = 10,
  }) async => BusinessPackagesResult.success(packages: []);

  @override
  Future<BusinessPackagesResult> getBusinessPackages(String businessId) async =>
      BusinessPackagesResult.success(packages: [_package]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('refreshes every 15 seconds, on tabs and resume; stops hidden', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var calls = 0;
    var tab = 0;
    late StateSetter update;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return CatalogRefresh(
              activeTab: tab,
              onRefresh: () => calls++,
              child: const Scaffold(body: Text('Catalog')),
            );
          },
        ),
      ),
    );
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 15));
    expect(calls, 1);
    update(() => tab = 1);
    await tester.pump();
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(calls, 3);
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Details')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 3);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15));
    expect(calls, 4);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 4);
  });

  testWidgets(
    'configured interval is respected and updates replace the timer',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var calls = 0;
      var interval = const Duration(seconds: 45);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CatalogRefresh(
                activeTab: 0,
                interval: interval,
                onRefresh: () => calls++,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 44));
      expect(calls, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      update(() => interval = const Duration(seconds: 30));
      await tester.pump();
      await tester.pump(const Duration(seconds: 29));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'home refresh bypasses cache, retains category and coalesces slow calls',
    () async {
      final repository = _PackagesRepository();
      final bloc = PackagesBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(
        const LoadPackagesByCategory(
          categoryId: '4',
          latitude: 41,
          longitude: 29,
        ),
      );
      await _flush();
      final states = <PackagesState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      final pending = Completer<PackagesResult>();
      repository.response = () => pending.future;
      bloc.refreshCurrent();
      bloc.refreshCurrent();
      await _flush();
      bloc.refreshCurrent();
      await _flush();
      expect(repository.queries, hasLength(2));
      expect(repository.queries.last, (
        lat: 41.0,
        lng: 29.0,
        category: '4',
        fresh: true,
      ));
      expect((bloc.state as PackagesLoaded).packages, [_package]);
      pending.complete(_packages([]));
      await _flush();
      expect((bloc.state as PackagesLoaded).packages, isEmpty);
      expect(states.whereType<PackagesLoading>(), isEmpty);
    },
  );

  test(
    'home background failure keeps data and a later refresh recovers',
    () async {
      final repository = _PackagesRepository();
      final bloc = PackagesBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(const LoadNearbyPackages(latitude: 41, longitude: 29));
      await _flush();
      repository.response = () async => PackagesResult.failure('offline');
      bloc.refreshCurrent();
      await _flush();
      expect((bloc.state as PackagesLoaded).packages, [_package]);
      repository.response = () async => _packages([]);
      bloc.refreshCurrent();
      await _flush();
      expect((bloc.state as PackagesLoaded).packages, isEmpty);
    },
  );

  test(
    'late package response cannot overwrite a newly selected category',
    () async {
      final old = Completer<PackagesResult>();
      final repository = _PackagesRepository()..response = () => old.future;
      final bloc = PackagesBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(const LoadNearbyPackages(latitude: 41, longitude: 29));
      await _flush();
      repository.response = () async => _packages([]);
      bloc.add(
        const LoadPackagesByCategory(
          categoryId: '4',
          latitude: 41,
          longitude: 29,
        ),
      );
      await _flush();
      old.complete(_packages([_package]));
      await _flush();
      expect((bloc.state as PackagesLoaded).packages, isEmpty);
    },
  );

  test(
    'map refresh preserves area and selection, removes deleted businesses',
    () async {
      final repository = _MapRepository();
      final bloc = MapBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(
        const LoadBusinessesForMap(latitude: 42, longitude: 30, radius: 4),
      );
      await _flush();
      bloc.add(SelectBusiness(business: repository.business));
      await _flush();
      final states = <MapState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      bloc.refreshCurrent();
      await _flush();
      expect((bloc.state as MapLoaded).selectedBusiness?.id, 'business');
      expect((bloc.state as MapLoaded).selectedPackage, _package);
      expect(repository.queries.last, (lat: 42.0, lng: 30.0, radius: 4.0));
      final pending = Completer<MapBusinessesResult>();
      repository.response = () => pending.future;
      bloc.refreshCurrent();
      bloc.refreshCurrent();
      await _flush();
      bloc.refreshCurrent();
      await _flush();
      expect(repository.queries, hasLength(3));
      expect((bloc.state as MapLoaded).businesses, isNotEmpty);
      pending.complete(MapBusinessesResult.success(businesses: []));
      await _flush();
      expect((bloc.state as MapLoaded).businesses, isEmpty);
      expect((bloc.state as MapLoaded).selectedBusiness, isNull);
      expect((bloc.state as MapLoaded).selectedPackage, isNull);
      expect(states.whereType<MapLoading>(), isEmpty);
    },
  );
}
