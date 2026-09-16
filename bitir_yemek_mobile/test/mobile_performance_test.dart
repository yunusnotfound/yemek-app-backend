import 'dart:async';
import 'dart:ui' as ui;

import 'package:bitir_yemek_mobile/core/services/cache_service.dart';
import 'package:bitir_yemek_mobile/core/services/location_service.dart';
import 'package:bitir_yemek_mobile/features/auth/presentation/pages/email_entry_page.dart';
import 'package:bitir_yemek_mobile/features/auth/presentation/pages/welcome_page.dart';
import 'package:bitir_yemek_mobile/features/home/data/models/business_model.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/services/map_marker_icons.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/services/marker_load_queue.dart';
import 'package:bitir_yemek_mobile/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Locations extends GeolocatorPlatform {
  Position? recent;
  Position? fresh;
  Completer<Position>? pending;
  int freshRequests = 0;
  int recentRequests = 0;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    recentRequests++;
    return recent;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    freshRequests++;
    settings = locationSettings;
    return pending?.future ?? Future.value(fresh!);
  }
}

Position _position({Duration age = Duration.zero, double accuracy = 20}) =>
    Position(
      longitude: 29.01,
      latitude: 41.01,
      timestamp: DateTime.now().subtract(age),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bounded response cache', () {
    final cache = CacheService();
    setUp(cache.clear);
    tearDown(cache.clear);

    test('evicts least recently used entries, keeping a strict capacity', () {
      for (var i = 0; i < CacheService.maxEntries; i++) {
        cache.set('page:$i', i);
      }
      expect(cache.get<int>('page:0'), 0);
      cache.set('new', 101);
      expect(cache.length, CacheService.maxEntries);
      expect(cache.get<int>('page:0'), 0);
      expect(cache.has('page:1'), isFalse);
    });

    test('replacing an entry does not evict an unrelated page', () {
      for (var i = 0; i < CacheService.maxEntries; i++) {
        cache.set('page:$i', i);
      }
      cache.set('page:20', 200);
      expect(cache.get<int>('page:0'), 0);
      expect(cache.get<int>('page:20'), 200);
      cache.set('page:20', 201, ttl: Duration.zero);
      expect(cache.has('page:20'), isFalse);
    });

    testWidgets('new writes remove unvisited expired pages', (tester) async {
      cache.set('old', 1, ttl: const Duration(milliseconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      cache.set('new', 2);
      expect(cache.length, 1);
      expect(cache.get<int>('old'), isNull);
    });
  });

  group('marker logo queue', () {
    test('500 logos never exceed four active requests', () async {
      final queue = MarkerLoadQueue<int>();
      var active = 0;
      var peak = 0;
      var completed = 0;
      queue.replace(List.generate(500, (i) => i), (item, isCurrent) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(Duration.zero);
        expect(isCurrent(), isTrue);
        active--;
        completed++;
      });
      await queue.settled;
      expect(peak, 4);
      expect(completed, 500);
    });

    test(
      'filter replacement cancels queued work and ignores stale results',
      () async {
        final queue = MarkerLoadQueue<int>(concurrency: 2);
        final unblock = Completer<void>();
        final started = <int>[];
        final updated = <int>[];
        queue.replace([1, 2, 3, 4], (item, isCurrent) async {
          started.add(item);
          await unblock.future;
          if (isCurrent()) updated.add(item);
        });
        queue.replace([10, 11], (item, isCurrent) async {
          started.add(item);
          if (isCurrent()) updated.add(item);
        });
        unblock.complete();
        await queue.settled;
        expect(started, [1, 2, 10, 11]);
        expect(updated, [10, 11]);
      },
    );

    test(
      'disposal prevents updates and a failed logo does not stop the queue',
      () async {
        final failures = <Object>[];
        final queue = MarkerLoadQueue<int>(
          concurrency: 1,
          onError: (error, _) => failures.add(error),
        );
        final updated = <int>[];
        queue.replace([1, 2], (item, isCurrent) async {
          if (item == 1) throw StateError('unavailable logo');
          if (isCurrent()) updated.add(item);
        });
        await queue.settled;
        expect(failures, hasLength(1));
        expect(updated, [2]);

        final unblock = Completer<void>();
        queue.replace([3, 4], (item, isCurrent) async {
          await unblock.future;
          if (isCurrent()) updated.add(item);
        });
        queue.cancel();
        unblock.complete();
        await queue.settled;
        expect(updated, [2]);
      },
    );

    testWidgets(
      'placeholder is available without downloading an unreachable logo',
      (tester) async {
        final business = BusinessModel.fromJson({
          'id': 'test',
          'name': 'Fırın',
          'imageUrl': 'https://unreachable.invalid/logo.jpg',
          'packageCount': 8,
          'category': {'id': 1, 'name': 'Fırın', 'slug': 'firin'},
        });
        final icons = MapMarkerIcons();
        await tester.runAsync(() async {
          final bytes = await icons.placeholder(business);
          expect(icons.cached(business), isNull);
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 192);
          expect(frame.image.height, 192);
          frame.image.dispose();
          codec.dispose();
          expect(identical(bytes, await icons.placeholder(business)), isTrue);
        });
      },
    );
  });

  group('bounded startup location', () {
    late GeolocatorPlatform original;
    late _Locations locations;
    setUp(() {
      original = GeolocatorPlatform.instance;
      locations = _Locations()..fresh = _position();
      GeolocatorPlatform.instance = locations;
    });
    tearDown(() => GeolocatorPlatform.instance = original);

    test('recent accurate location avoids a GPS fix', () async {
      locations.recent = _position(age: const Duration(seconds: 30));
      final result = await LocationService().getCurrentPosition(
        preferRecent: true,
      );
      expect(result, same(locations.recent));
      expect(locations.freshRequests, 0);
    });

    test(
      'stale, inaccurate and future-dated cached locations require a fix',
      () async {
        for (final recent in [
          _position(age: const Duration(minutes: 3)),
          _position(accuracy: 1000),
          _position(age: const Duration(minutes: -1)),
        ]) {
          locations.recent = recent;
          final result = await LocationService().getCurrentPosition(
            preferRecent: true,
          );
          expect(result, same(locations.fresh));
        }
        expect(locations.freshRequests, 3);
        expect(locations.settings?.accuracy, LocationAccuracy.medium);
        expect(locations.settings?.timeLimit, const Duration(seconds: 4));
      },
    );

    test(
      'explicit location refresh does not reuse cached coordinates',
      () async {
        locations.recent = _position();
        expect(
          await LocationService().getCurrentPosition(),
          same(locations.fresh),
        );
        expect(locations.recentRequests, 0);
      },
    );

    testWidgets('unresponsive GPS falls back in four seconds', (tester) async {
      locations.pending = Completer<Position>();
      var completed = false;
      Position? result;
      final pending = LocationService().getCurrentPosition().then((position) {
        result = position;
        completed = true;
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await pending;
      expect(completed, isTrue);
      expect(result, isNull);
      locations.pending!.complete(locations.fresh!);
    });
  });

  group('splash routing', () {
    const storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async => null);
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, null);
    });

    testWidgets('returning signed-out user sees the full scene before login', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'has_signed_in_before': true});
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(EmailEntryPage), findsNothing);
      await tester.pump(const Duration(milliseconds: 3700));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EmailEntryPage), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('first-time user retains the complete opening scene', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(WelcomePage), findsNothing);
      await tester.pump(const Duration(milliseconds: 3700));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WelcomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
