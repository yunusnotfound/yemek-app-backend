import 'dart:async';

import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/package_model.dart';
import 'package:bitir_yemek_mobile/features/map/data/repositories/map_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/map/domain/repositories/map_repository.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_bloc.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_event.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/bloc/map_state.dart';
import 'package:flutter_test/flutter_test.dart';

BusinessModel _business(String id) => BusinessModel.fromJson({
  'id': id,
  'name': id,
  'latitude': 41.0,
  'longitude': 29.0,
  'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin'},
});

final _package = PackageModel.fromJson({
  'id': 'package',
  'businessId': 'b',
  'title': 'Paket',
  'originalPrice': 200,
  'discountedPrice': 100,
  'quantity': 5,
  'remainingQuantity': 5,
  'pickupDate': '2099-01-01',
  'pickupStart': '18:00',
  'pickupEnd': '20:00',
  'business': {
    'id': 'b',
    'name': 'Fırın',
    'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin'},
  },
});

class _Repository implements MapRepository {
  Future<MapBusinessesResult> Function(double lat)? businesses;
  final packageRequests = <double>[];
  Completer<BusinessPackagesResult>? selectedPackages;
  Completer<DirectionsResult>? directions;

  @override
  Future<MapBusinessesResult> getBusinessesForMap({
    required double lat,
    required double lng,
    double radius = 10,
  }) async =>
      businesses?.call(lat) ??
      MapBusinessesResult.success(businesses: [_business('b')]);

  @override
  Future<BusinessPackagesResult> getNearbyPackages({
    required double lat,
    required double lng,
    double radius = 10,
  }) async {
    packageRequests.add(lat);
    return BusinessPackagesResult.success(packages: [_package]);
  }

  @override
  Future<BusinessPackagesResult> getBusinessPackages(String businessId) async =>
      selectedPackages?.future ??
      BusinessPackagesResult.success(packages: [_package]);

  @override
  Future<DirectionsResult> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async => directions!.future;
}

const _load = LoadBusinessesForMap(latitude: 41, longitude: 29);
const _directions = RequestDirections(
  originLat: 41,
  originLng: 29,
  destLat: 41.01,
  destLng: 29.01,
);
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'changing location discards the old response and its package request',
    () async {
      final oldResponse = Completer<MapBusinessesResult>();
      final repository = _Repository()
        ..businesses = (lat) async => lat == 41
            ? oldResponse.future
            : MapBusinessesResult.success(businesses: [_business('new')]);
      final bloc = MapBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(_load);
      await _flush();
      bloc.add(const LoadBusinessesForMap(latitude: 42, longitude: 29));
      await _flush();
      oldResponse.complete(
        MapBusinessesResult.success(businesses: [_business('old')]),
      );
      await _flush();
      expect((bloc.state as MapLoaded).businesses.single.id, 'new');
      expect(repository.packageRequests, [42]);
    },
  );

  test(
    'directions arriving after package details preserve the latest card',
    () async {
      final repository = _Repository()
        ..selectedPackages = Completer<BusinessPackagesResult>()
        ..directions = Completer<DirectionsResult>();
      final bloc = MapBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(_load);
      await _flush();
      bloc.add(SelectBusiness(business: _business('b')));
      await _flush();
      bloc.add(_directions);
      await _flush();
      repository.selectedPackages!.complete(
        BusinessPackagesResult.success(packages: [_package]),
      );
      await _flush();
      repository.directions!.complete(
        DirectionsResult.success(directions: {'distance': 100}),
      );
      await _flush();
      final state = bloc.state as MapLoaded;
      expect(state.selectedPackage, _package);
      expect(state.packageLoading, isFalse);
      expect(state.packages, [_package]);
      expect(state.directions?['distance'], 100);
    },
  );

  test('closing a selected card ignores a late route response', () async {
    final repository = _Repository()
      ..directions = Completer<DirectionsResult>();
    final bloc = MapBloc(repository: repository);
    addTearDown(bloc.close);
    bloc.add(_load);
    await _flush();
    bloc.add(SelectBusiness(business: _business('b')));
    await _flush();
    bloc.add(_directions);
    await _flush();
    bloc.add(const ClearSelection());
    await _flush();
    repository.directions!.complete(
      DirectionsResult.success(directions: {'distance': 100}),
    );
    await _flush();
    expect((bloc.state as MapLoaded).selectedBusiness, isNull);
    expect((bloc.state as MapLoaded).directions, isNull);
  });
}
