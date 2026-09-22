import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../core/services/location_service.dart';
import '../../../business_owner/presentation/pages/business_owner_scaffold.dart';
import '../../../main/presentation/pages/main_scaffold.dart';
import 'manual_location_page.dart';
import '../widgets/location_discovery_hero.dart';

class LocationPermissionPage extends StatefulWidget {
  final bool isBusinessOwner;

  const LocationPermissionPage({super.key, this.isBusinessOwner = false});

  @override
  State<LocationPermissionPage> createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  bool _isSelecting = false;

  Future<void> _useCurrentLocation() async {
    if (_isLoading || _isSelecting) return;
    setState(() => _isLoading = true);
    try {
      final enabled = await _locationService.isLocationServiceEnabled();
      if (!mounted) return;
      if (!enabled) {
        _showError(
          'Konum servislerini açabilir veya Konum seç ile devam edebilirsin.',
        );
        return;
      }

      final permission = await _locationService.requestPermission();
      if (!mounted) return;
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showError(
          'Konum izni olmadan da Konum seç ile bölgeni belirleyebilirsin.',
        );
        return;
      }

      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        _showError('Konum alınamadı. Konum seç ile bölgeni belirleyebilirsin.');
        return;
      }
      _continue(position.latitude, position.longitude);
    } catch (_) {
      _showError(
        'Konum alınamadı. Tekrar deneyebilir veya bölgeni seçebilirsin.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectLocation() async {
    if (_isLoading || _isSelecting) return;
    setState(() => _isSelecting = true);
    try {
      final location = await Navigator.of(context).push<ManualLocation>(
        MaterialPageRoute(builder: (_) => const ManualLocationPage()),
      );
      if (!mounted || location == null) return;
      _continue(location.latitude, location.longitude);
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  void _continue(double latitude, double longitude) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => widget.isBusinessOwner
            ? const BusinessOwnerScaffold()
            : MainScaffold(latitude: latitude, longitude: longitude),
      ),
      (_) => false,
    );
  }

  void _showError(String message) {
    if (mounted) AppNotice.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isSelecting;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFAF5), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 432,
                    minHeight: (constraints.maxHeight - 32).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          const LocationDiscoveryHero(),
                          const SizedBox(height: 28),
                          Text(
                            'Güzel bir keşif,\nyakınında başlar.',
                            style: AppTypography.h1.copyWith(
                              fontSize: 34,
                              height: 1.08,
                              letterSpacing: -0.9,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Konumunu belirle, çevrendeki lezzetleri keşfet. '
                            'Kurtarılmayı bekleyen paketlerle tanış.',
                            style: AppTypography.bodyLarge.copyWith(
                              height: 1.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: busy ? null : _useCurrentLocation,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 58),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                        semanticsLabel: 'Konumun alınıyor',
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.my_location_rounded,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            'Mevcut konumumu kullan',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: busy ? null : _selectLocation,
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.creamTop,
                                foregroundColor: AppColors.ink,
                                minimumSize: const Size(0, 54),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: const BorderSide(
                                    color: AppDepth.border,
                                  ),
                                ),
                                textStyle: AppTypography.button,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map_outlined, size: 20),
                                  SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Konum seç',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Konumun, yakınındaki paketleri göstermek için kullanılır. '
                              'İzin vermeden de bölgeni seçebilirsin.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.inkSoft,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 34,
            height: 34,
            cacheWidth: 102,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'BitirGitsin',
            style: AppTypography.h3.copyWith(
              color: AppColors.ink,
              fontSize: 22,
              letterSpacing: -0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8DC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'KEŞFET',
              style: AppTypography.caption.copyWith(
                color: AppColors.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
