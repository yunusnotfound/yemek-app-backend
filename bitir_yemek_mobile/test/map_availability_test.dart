import 'dart:async';

import 'package:bitir_yemek_mobile/core/network/dio_client.dart';
import 'package:bitir_yemek_mobile/core/utils/package_availability.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/package_model.dart';
import 'package:bitir_yemek_mobile/features/map/data/datasources/map_remote_datasource.dart';
import 'package:bitir_yemek_mobile/features/map/data/repositories/map_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/map/domain/repositories/map_repository.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_bloc.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_event.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _business(String id) => {
  'id': id,
  'name': id,
  'latitude': 41.0,
  'longitude': 29.0,
  'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin'},
};

Map<String, dynamic> _package(
  String id, {
  String businessId = 'b',
  String pickupDate = '2099-01-01',
  String pickupStart = '18:00',
  String pickupEnd = '20:00',
  int remainingQuantity = 5,
  bool isActive = true,
  bool isSuspended = false,
}) => {
  'id': id,
  'businessId': businessId,
  'title': id,
  'originalPrice': 200,
  'discountedPrice': 100,
  'quantity': 5,
  'remainingQuantity': remainingQuantity,
  'isActive': isActive,
  'isSuspended': isSuspended,
  'pickupDate': pickupDate,
  'pickupStart': pickupStart,
  'pickupEnd': pickupEnd,
  'business': _business(businessId),
};

class _Repository implements MapRepository {
  List<BusinessModel> businesses = [BusinessModel.fromJson(_business('b'))];
  List<PackageModel> nearby = [PackageModel.fromJson(_package('live'))];
  List<PackageModel> details = [PackageModel.fromJson(_package('live'))];
  Completer<BusinessPackagesResult>? nearbyResponse;
  Completer<MapBusinessesResult>? businessResponse;
  @override
  Future<MapBusinessesResult> getBusinessesForMap({
    required double lat,
    required double lng,
    double radius = 10,
  }) async =>
      businessResponse?.future ??
      MapBusinessesResult.success(businesses: businesses);

  @override
  Future<BusinessPackagesResult> getNearbyPackages({
    required double lat,
    required double lng,
    double radius = 10,
  }) async =>
      nearbyResponse?.future ??
      BusinessPackagesResult.success(packages: nearby);

  @override
  Future<BusinessPackagesResult> getBusinessPackages(String businessId) async =>
      BusinessPackagesResult.success(packages: details);

  @override
  Future<DirectionsResult> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async => DirectionsResult.success(directions: {'distance': 100});
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
const _load = LoadBusinessesForMap(latitude: 41, longitude: 29);

void main() {
  test('pickup cutoff is Istanbul time and expires exactly at the end', () {
    final package = _package('p', pickupDate: '2026-09-24');
    expect(packagePickupEnd(package), DateTime.utc(2026, 9, 24, 17));
    expect(
      isPackageAvailable(package, now: DateTime.utc(2026, 9, 24, 16, 59, 59)),
      isTrue,
    );
    expect(
      isPackageAvailable(package, now: DateTime.utc(2026, 9, 24, 17)),
      isFalse,
    );
    expect(
      isPackageAvailable({
        ...package,
        'remainingQuantity': 0,
      }, now: DateTime.utc(2026, 9, 24)),
      isFalse,
    );
    expect(
      isPackageAvailable({
        ...package,
        'isSuspended': true,
      }, now: DateTime.utc(2026, 9, 24)),
      isFalse,
    );
    expect(
      isPackageAvailable({
        ...package,
        'isActive': false,
      }, now: DateTime.utc(2026, 9, 24)),
      isFalse,
    );
  });

  test(
    'overnight pickup survives midnight and malformed windows fail closed',
    () {
      final package = _package(
        'p',
        pickupDate: '2026-09-24',
        pickupStart: '23:00:00',
        pickupEnd: '01:00:00',
      );
      expect(packagePickupEnd(package), DateTime.utc(2026, 9, 24, 22));
      expect(
        isPackageAvailable(package, now: DateTime.utc(2026, 9, 24, 21, 30)),
        isTrue,
      );
      expect(
        isPackageAvailable(package, now: DateTime.utc(2026, 9, 24, 22)),
        isFalse,
      );
      expect(
        packagePickupEnd({...package, 'pickupEnd': '23:00'}),
        DateTime.utc(2026, 9, 25, 20),
      );
      expect(packagePickupEnd({...package, 'pickupEnd': '25:00'}), isNull);
      expect(
        packagePickupEnd({...package, 'pickupDate': '2026-02-30'}),
        isNull,
      );
    },
  );

  test(
    'map metadata excludes unavailable businesses and corrects counts without detail requests',
    () async {
      final client = DioClient();
      addTearDown(() => client.dio.close());
      final requests = <String>[];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request.path);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'businesses': [
                    {
                      ..._business('expired'),
                      'packages': [_package('old', pickupDate: '2000-01-01')],
                    },
                    {
                      ..._business('empty'),
                      'packages': [_package('sold', remainingQuantity: 0)],
                    },
                    {
                      ..._business('live'),
                      'packageCount': 99,
                      'availableNow': true,
                      'packages': [
                        _package('future', businessId: 'live'),
                        _package(
                          'later',
                          businessId: 'live',
                          pickupDate: '2099-01-02',
                        ),
                        _package(
                          'old',
                          businessId: 'live',
                          pickupDate: '2000-01-01',
                        ),
                        _package(
                          'blocked',
                          businessId: 'live',
                          isSuspended: true,
                        ),
                      ],
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final result = await MapRemoteDataSource(
        dioClient: client,
      ).getBusinessesForMap(latitude: 41, longitude: 29);
      expect(result.map((business) => business.id), ['live']);
      expect(result.single.packageCount, 2);
      expect(result.single.availableNow, isFalse);
      expect(result.single.availableUntil, DateTime.utc(2099, 1, 2, 17));
      expect(requests, ['/maps/nearby']);
    },
  );

  test(
    'legacy map fallback resolves each business with at most four requests at once',
    () async {
      final client = DioClient();
      addTearDown(() => client.dio.close());
      var active = 0;
      var maxActive = 0;
      final detailIds = <String>[];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            if (request.path == '/maps/nearby') {
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    'businesses': List.generate(9, (i) => _business('$i')),
                  },
                ),
              );
              return;
            }
            final id = request.path.split('/').last;
            detailIds.add(id);
            active++;
            if (active > maxActive) maxActive = active;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            active--;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'business': {
                    ..._business(id),
                    'packages': [
                      _package(
                        'p$id',
                        businessId: id,
                        pickupDate: id == '0' ? '2000-01-01' : '2099-01-01',
                      ),
                    ],
                  },
                },
              ),
            );
          },
        ),
      );
      final result = await MapRemoteDataSource(
        dioClient: client,
      ).getBusinessesForMap(latitude: 41, longitude: 29);
      expect(result.map((business) => business.id), [
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
      ]);
      expect(detailIds.toSet().length, 9);
      expect(maxActive, lessThanOrEqualTo(4));
    },
  );

  test(
    'map package data sources filter expiry, stock, and suspended packages',
    () async {
      final client = DioClient();
      addTearDown(() => client.dio.close());
      final packages = [
        _package('live'),
        _package('old', pickupDate: '2000-01-01'),
        _package('empty', remainingQuantity: 0),
        _package('inactive', isActive: false),
        _package('suspended', isSuspended: true),
      ];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                data: request.path == '/packages'
                    ? {'data': packages}
                    : {
                        'business': {..._business('b'), 'packages': packages},
                      },
              ),
            );
          },
        ),
      );
      final source = MapRemoteDataSource(dioClient: client);
      expect(
        (await source.getBusinessPackages('b')).map((package) => package.id),
        ['live'],
      );
      expect(
        (await source.getNearbyPackages(
          latitude: 41,
          longitude: 29,
        )).map((package) => package.id),
        ['live'],
      );
    },
  );

  test(
    'refresh removes vanished selection, route and stale package sheet before packages finish',
    () async {
      final repository = _Repository();
      final bloc = MapBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(_load);
      await _flush();
      bloc.add(SelectBusiness(business: repository.businesses.single));
      await _flush();
      bloc.add(
        const RequestDirections(
          originLat: 41,
          originLng: 29,
          destLat: 41.1,
          destLng: 29.1,
        ),
      );
      await _flush();
      expect((bloc.state as MapLoaded).selectedPackage, isNotNull);
      repository.businesses = [];
      repository.nearbyResponse = Completer<BusinessPackagesResult>();
      bloc.refreshCurrent();
      await _flush();
      final state = bloc.state as MapLoaded;
      expect(state.businesses, isEmpty);
      expect(state.selectedBusiness, isNull);
      expect(state.selectedPackage, isNull);
      expect(state.directions, isNull);
      expect(state.packages, isEmpty);
      repository.nearbyResponse!.complete(
        BusinessPackagesResult.failure('Offline'),
      );
      await _flush();
      expect((bloc.state as MapLoaded).packagesLoading, isFalse);
    },
  );

  test(
    'local cutoff clears expired map state while background refresh fails',
    () async {
      var now = DateTime.utc(2026, 9, 24, 16, 59);
      final expiring = PackageModel.fromJson(
        _package('expiring', pickupDate: '2026-09-24'),
      );
      final repository = _Repository()
        ..businesses = [
          BusinessModel.fromJson({
            ..._business('b'),
            'availableUntil': '2026-09-24T17:00:00Z',
          }),
          BusinessModel.fromJson({
            ..._business('future'),
            'availableUntil': '2026-09-24T18:00:00Z',
          }),
          BusinessModel.fromJson(_business('unknown')),
        ]
        ..nearby = [expiring]
        ..details = [expiring];
      final bloc = MapBloc(repository: repository, now: () => now);
      addTearDown(bloc.close);
      bloc.add(_load);
      await _flush();
      bloc.add(SelectBusiness(business: repository.businesses.first));
      await _flush();
      bloc.add(
        const RequestDirections(
          originLat: 41,
          originLng: 29,
          destLat: 41.1,
          destLng: 29.1,
        ),
      );
      await _flush();
      expect((bloc.state as MapLoaded).selectedPackage, expiring);
      expect((bloc.state as MapLoaded).directions, isNotNull);

      now = DateTime.utc(2026, 9, 24, 17);
      repository.businessResponse = Completer<MapBusinessesResult>();
      bloc.refreshCurrent();
      await _flush();
      final state = bloc.state as MapLoaded;
      // Future and unknown businesses survive even if absent from the package
      // page. The known expired marker disappears before any network response.
      expect(state.businesses.map((business) => business.id), [
        'future',
        'unknown',
      ]);
      expect(state.packages, isEmpty);
      expect(state.selectedBusiness, isNull);
      expect(state.selectedPackage, isNull);
      expect(state.directions, isNull);
      repository.businessResponse!.complete(
        MapBusinessesResult.failure('Offline'),
      );
      await _flush();
      expect(bloc.state, state);
    },
  );

  test(
    'expired selected package clears its card without hiding a business with later packages',
    () async {
      var now = DateTime.utc(2026, 9, 24, 16, 59);
      final expiring = PackageModel.fromJson(
        _package('expiring', pickupDate: '2026-09-24'),
      );
      final repository = _Repository()
        ..businesses = [
          BusinessModel.fromJson({
            ..._business('b'),
            'availableUntil': '2026-09-24T18:00:00Z',
          }),
        ]
        ..nearby = [expiring]
        ..details = [expiring];
      final bloc = MapBloc(repository: repository, now: () => now);
      addTearDown(bloc.close);
      bloc.add(_load);
      await _flush();
      bloc.add(SelectBusiness(business: repository.businesses.single));
      await _flush();
      now = DateTime.utc(2026, 9, 24, 17);
      repository.businessResponse = Completer<MapBusinessesResult>();
      bloc.refreshCurrent();
      await _flush();
      repository.businessResponse!.complete(
        MapBusinessesResult.failure('Offline'),
      );
      await _flush();
      final state = bloc.state as MapLoaded;
      expect(state.businesses.single.id, 'b');
      expect(state.selectedBusiness, isNull);
      expect(state.selectedPackage, isNull);
      expect(state.packages, isEmpty);
    },
  );

  test(
    'selecting a business whose last package expired removes its marker',
    () async {
      final repository = _Repository()
        ..details = [
          PackageModel.fromJson(_package('old', pickupDate: '2000-01-01')),
        ];
      final bloc = MapBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(_load);
      await _flush();
      bloc.add(SelectBusiness(business: repository.businesses.single));
      await _flush();
      final state = bloc.state as MapLoaded;
      expect(state.businesses, isEmpty);
      expect(state.selectedBusiness, isNull);
      expect(state.selectedPackage, isNull);
      expect(state.packages, isEmpty);
    },
  );
}
