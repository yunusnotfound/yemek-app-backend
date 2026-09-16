import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../core/services/location_service.dart';
import '../../../business_owner/presentation/pages/business_owner_scaffold.dart';
import '../../../main/presentation/pages/main_scaffold.dart';
import 'manual_location_page.dart';

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: AppDepth.surface(
                            radius: AppRadius.full,
                            warm: true,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Paketleri nerede bulmak istersin?',
                          textAlign: TextAlign.center,
                          style: AppTypography.h2,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Yakınındaki fırsatları görmek için konumunu kullan veya bölgeni kendin seç.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: busy ? null : _useCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          shape: const StadiumBorder(),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Mevcut konumumu kullan',
                                textAlign: TextAlign.center,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: busy ? null : _selectLocation,
                        child: const Text(
                          'Konum seç',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
