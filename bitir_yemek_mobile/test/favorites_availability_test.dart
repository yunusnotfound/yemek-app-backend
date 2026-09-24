import 'dart:async';

import 'package:bitir_yemek_mobile/core/network/dio_client.dart';
import 'package:bitir_yemek_mobile/core/services/cache_service.dart';
import 'package:bitir_yemek_mobile/features/favorites/data/datasources/favorites_remote_datasource.dart';
import 'package:bitir_yemek_mobile/features/favorites/data/models/favorite_model.dart';
import 'package:bitir_yemek_mobile/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:bitir_yemek_mobile/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:bitir_yemek_mobile/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.parse('2026-09-24T12:00:00Z');

Map<String, dynamic> _package({String end = '16:00'}) => {
  'id': 'package',
  'pickupDate': '2026-09-24',
  'pickupStart': '10:00',
  'pickupEnd': end,
  'isActive': true,
  'isSuspended': false,
  'remainingQuantity': 1,
};

Map<String, dynamic> _row(String id, {List<dynamic>? packages}) => {
  'id': 'favorite-$id',
  'businessId': id,
  'createdAt': '2026-09-24T08:00:00Z',
  'business': {'id': id, 'name': id, 'packages': ?packages},
};

FavoriteModel _favorite(String id, {String end = '16:00'}) =>
    FavoriteModel.fromJson(_row(id, packages: [_package(end: end)]));

FavoritesResponse _page(
  List<FavoriteModel> rows, {
  int page = 1,
  int pages = 1,
}) => FavoritesResponse(
  favorites: rows,
  total: rows.length,
  page: page,
  totalPages: pages,
);

Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Repository implements FavoritesRepository {
  final calls = <({int page, bool fresh})>[];
  final removed = <String>[];
  Future<FavoritesResponse> Function(int) response = (_) async => _page([]);

  @override
  Future<FavoritesResponse> getFavorites({
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
  }) {
    calls.add((page: page, fresh: forceRefresh));
    return response(page);
  }

  @override
  Future<void> addFavorite(String businessId) async {}

  @override
  Future<void> removeFavorite(String businessId) async {
    removed.add(businessId);
  }

  @override
  Future<bool> checkFavorite(String businessId) async => false;
}

class _Remote extends FavoritesRemoteDataSource {
  _Remote() : super(dioClient: DioClient());

  int lists = 0;
  int details = 0;
  int activeDetails = 0;
  int peakDetails = 0;
  List<Map<String, dynamic>> rows = [];
  List<dynamic> packages = [_package()];

  @override
  Future<Map<String, dynamic>> getFavorites({
    int page = 1,
    int limit = 10,
  }) async {
    lists++;
    return {
      'data': rows,
      'pagination': {'page': 1, 'totalPages': 1, 'total': rows.length},
    };
  }

  @override
  Future<List<dynamic>> getBusinessPackages(String businessId) async {
    details++;
    activeDetails++;
    if (activeDetails > peakDetails) peakDetails = activeDetails;
    await Future<void>.delayed(Duration.zero);
    activeDetails--;
    return packages;
  }
}

void main() {
  setUp(() => CacheService().clear());
  tearDown(() => CacheService().clear());

  test('expired cards disappear while saved favorite IDs remain', () async {
    final repository = _Repository()
      ..response = (_) async => _page([
        _favorite('expired', end: '15:00'),
        _favorite('available'),
        FavoriteModel.fromJson(_row('empty', packages: [])),
      ]);
    final bloc = FavoritesBloc(repository: repository, now: () => _now);
    addTearDown(bloc.close);
    bloc.add(const LoadFavorites());
    await _flush();

    final state = bloc.state as FavoritesLoaded;
    expect(state.favorites.map((favorite) => favorite.businessId), [
      'available',
    ]);
    expect(state.savedBusinessIds, {'expired', 'available', 'empty'});
    expect(bloc.isFavorite('expired'), isTrue);
    expect(repository.removed, isEmpty);

    // A hidden saved favorite must toggle to removal, never a duplicate add.
    bloc.add(const ToggleFavorite(businessId: 'expired'));
    await _flush();
    expect(repository.removed, ['expired']);
    expect(bloc.isFavorite('expired'), isFalse);
    expect(bloc.isFavorite('empty'), isTrue);
  });

  test(
    'hidden pages cannot strand available favorites on later pages',
    () async {
      final repository = _Repository()
        ..response = (page) async => _page(
          page < 3
              ? List.generate(
                  10,
                  (index) => _favorite('$page-$index', end: '15:00'),
                )
              : [_favorite('available')],
          page: page,
          pages: 3,
        );
      final bloc = FavoritesBloc(repository: repository, now: () => _now);
      addTearDown(bloc.close);
      bloc.add(const LoadFavorites());
      await _flush();

      expect(repository.calls.map((call) => call.page), [1, 2, 3]);
      final state = bloc.state as FavoritesLoaded;
      expect(state.favorites.single.businessId, 'available');
      expect(state.hasReachedMax, isTrue);
      expect(state.savedBusinessIds, hasLength(21));
    },
  );

  test(
    'refresh retains loaded pages and bypasses cache on every page',
    () async {
      final repository = _Repository()
        ..response = (page) async => _page(
          List.generate(10, (index) => _favorite('$page-$index')),
          page: page,
          pages: 2,
        );
      final bloc = FavoritesBloc(repository: repository, now: () => _now);
      addTearDown(bloc.close);
      bloc.add(const LoadFavorites());
      await _flush();
      bloc.add(const LoadMoreFavorites());
      await _flush();
      expect((bloc.state as FavoritesLoaded).favorites, hasLength(20));

      bloc.refreshCurrent();
      await _flush();
      expect(repository.calls, [
        (page: 1, fresh: false),
        (page: 2, fresh: false),
        (page: 1, fresh: true),
        (page: 2, fresh: true),
      ]);
      expect((bloc.state as FavoritesLoaded).favorites, hasLength(20));
    },
  );

  test(
    'expiry is applied during a failed background request and recovers',
    () async {
      var now = _now;
      final repository = _Repository()
        ..response = (_) async => _page([_favorite('business', end: '15:01')]);
      final bloc = FavoritesBloc(repository: repository, now: () => now);
      addTearDown(bloc.close);
      bloc.add(const LoadFavorites());
      await _flush();
      expect((bloc.state as FavoritesLoaded).favorites, hasLength(1));

      now = now.add(const Duration(minutes: 1));
      final pending = Completer<FavoritesResponse>();
      repository.response = (_) => pending.future;
      bloc.refreshCurrent();
      bloc.refreshCurrent();
      await _flush();
      bloc.refreshCurrent();
      await _flush();
      expect(repository.calls, hasLength(2));
      expect((bloc.state as FavoritesLoaded).favorites, isEmpty);
      expect(bloc.isFavorite('business'), isTrue);
      pending.completeError(Exception('offline'));
      await _flush();
      expect(bloc.state, isA<FavoritesLoaded>());
      expect((bloc.state as FavoritesLoaded).savedBusinessIds, {'business'});

      repository.response = (_) async => _page([_favorite('business')]);
      bloc.refreshCurrent();
      await _flush();
      expect((bloc.state as FavoritesLoaded).favorites, hasLength(1));
      expect(bloc.isFavorite('business'), isTrue);
    },
  );

  test('background responses cannot undo a queued favorite removal', () async {
    final repository = _Repository()
      ..response = (_) async => _page([_favorite('business')]);
    final bloc = FavoritesBloc(repository: repository, now: () => _now);
    addTearDown(bloc.close);
    bloc.add(const LoadFavorites());
    await _flush();
    final pending = Completer<FavoritesResponse>();
    repository.response = (_) => pending.future;
    bloc.refreshCurrent();
    await _flush();
    bloc.add(const ToggleFavorite(businessId: 'business'));
    await _flush();
    expect(repository.removed, isEmpty);
    pending.complete(_page([_favorite('business')]));
    await _flush();
    expect(repository.removed, ['business']);
    expect(bloc.isFavorite('business'), isFalse);
    expect((bloc.state as FavoritesLoaded).favorites, isEmpty);
  });

  test(
    'metadata avoids detail requests and a refresh bypasses list cache',
    () async {
      final remote = _Remote()
        ..rows = [
          _row('business', packages: [_package()]),
        ];
      final repository = FavoritesRepositoryImpl(remoteDataSource: remote);
      expect(
        (await repository.getFavorites()).favorites.single.hasAvailablePackage(
          now: _now,
        ),
        isTrue,
      );
      remote.rows = [_row('business', packages: [])];
      expect(
        (await repository.getFavorites()).favorites.single.hasAvailablePackage(
          now: _now,
        ),
        isTrue,
      );
      expect(remote.lists, 1);
      expect(
        (await repository.getFavorites(
          forceRefresh: true,
        )).favorites.single.hasAvailablePackage(now: _now),
        isFalse,
      );
      expect(remote.lists, 2);
      expect(remote.details, 0);
    },
  );

  test(
    'older responses hydrate availability with bounded detail concurrency',
    () async {
      final remote = _Remote()
        ..rows = List.generate(9, (index) => _row('$index'));
      final repository = FavoritesRepositoryImpl(remoteDataSource: remote);
      final response = await repository.getFavorites();
      expect(response.favorites, hasLength(9));
      expect(
        response.favorites.every(
          (favorite) => favorite.hasAvailablePackage(now: _now),
        ),
        isTrue,
      );
      expect(remote.details, 9);
      expect(remote.peakDetails, lessThanOrEqualTo(4));
      await repository.getFavorites();
      expect(remote.details, 9);
      remote.packages = [_package(end: '15:00')];
      final refreshed = await repository.getFavorites(forceRefresh: true);
      expect(
        refreshed.favorites.every(
          (favorite) => favorite.hasAvailablePackage(now: _now),
        ),
        isFalse,
      );
      expect(
        refreshed.favorites.map((favorite) => favorite.businessId),
        response.favorites.map((favorite) => favorite.businessId),
      );
    },
  );
}
