import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../auth/presentation/pages/email_entry_page.dart';
import '../../../auth/presentation/pages/welcome_page.dart';
import '../../../business_owner/presentation/pages/business_owner_scaffold.dart';
import '../../../location/presentation/pages/location_permission_page.dart';
import '../../../main/presentation/pages/main_scaffold.dart';
import '../widgets/aurora_scene.dart';
import '../widgets/scene_palette.dart';

/// Uygulamanın açılış ekranı: her başlatmada gösterilir.
///
/// İki iş paralel yürür — sahne oynar, arkada oturum/konum kontrolü yapılır.
/// Yönlendirme İKİSİ de bittiğinde gerçekleşir: kontrol erken biterse sahne
/// kırpılmaz, sahne erken biterse kontrol beklenir. Böylece açılış ne yarım
/// kalır ne de kullanıcıyı gereksiz bekletir.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// Sahne animasyonunun bittiğini bildiren kapı.
  final Completer<void> _sceneDone = Completer<void>();

  /// Palet açılış anında bir kez seçilir; ekran ortasında renk değiştirmesin.
  late final ScenePalette _palette;

  @override
  void initState() {
    super.initState();
    _palette = ScenePalette.brand;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final destination = await _resolveDestination();
    await _sceneDone.future;
    if (!mounted) return;

    Navigator.of(context).pushReplacement(_fadeRoute(destination));
  }

  /// Oturum + konum durumuna göre gidilecek ekranı belirler.
  ///
  /// Bu adımlardaki herhangi bir hata (güvenli depolama, konum eklentisi)
  /// kullanıcıyı açılış ekranında asılı bırakmamalı; hatada her zaman
  /// erişilebilir bir hedef olan [WelcomePage]'e düşülür.
  Future<Widget> _resolveDestination() async {
    try {
      final locationService = LocationService();

      // Birbirinden bağımsız okumaları paralel yürüt — dönen kullanıcıda açılışı
      // hızlandırır (token, rol ve izin kontrolü ardışık beklemez).
      final results = await Future.wait([
        appTokenStorage.getAccessToken(),
        appTokenStorage.getUserRole(),
        locationService.hasPermission(),
        appOnboardingStorage.hasSignedInBefore(),
      ]);
      final accessToken = results[0] as String?;
      final role = results[1] as String?;
      final hasPermission = results[2] as bool;
      final signedInBefore = results[3] as bool;

      // Oturum yok. Bu cihazda daha önce bir hesaba girilmişse tanıtımı
      // atlayıp doğrudan girişe götür — dönen kullanıcıyı üç tanıtım
      // sayfasından tekrar geçirmenin anlamı yok.
      if (accessToken == null || accessToken.isEmpty) {
        return signedInBefore ? const EmailEntryPage() : const WelcomePage();
      }

      final isBusinessOwner = role == 'business_owner';

      if (hasPermission) {
        if (isBusinessOwner) {
          return const BusinessOwnerScaffold();
        }

        final position = await locationService.getCurrentPosition();
        if (position != null) {
          return MainScaffold(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      }

      // No location permission yet (or position unavailable)
      return LocationPermissionPage(isBusinessOwner: isBusinessOwner);
    } catch (e, stack) {
      reportError(e, stack);
      // Safe fallback so the user is never stranded on the splash screen.
      return const WelcomePage();
    }
  }

  /// Sahneden uygulamaya yumuşak bir sönümlemeyle geçilir; splash'ın sıcak
  /// zemini bir anda kesilmesin.
  Route<void> _fadeRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.04, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLightOnDark = _palette.statusIcons == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Android ikon rengi ile iOS'un zemin-parlaklığı beklentisi terstir.
        statusBarIconBrightness: isLightOnDark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isLightOnDark
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _palette.skyBottom,
        body: AuroraScene(
          palette: _palette,
          onComplete: () {
            if (!_sceneDone.isCompleted) _sceneDone.complete();
          },
        ),
      ),
    );
  }
}
