import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../core/services/location_service.dart';
import '../../../business_owner/presentation/pages/business_owner_scaffold.dart';
import '../../../main/presentation/pages/main_scaffold.dart';

class LocationPermissionPage extends StatefulWidget {
  final bool isBusinessOwner;

  const LocationPermissionPage({super.key, this.isBusinessOwner = false});

  @override
  State<LocationPermissionPage> createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Lütfen konum servislerini açın');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Request permission
      LocationPermission permission = await _locationService
          .requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Konum izni gereklidir');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get current position
      final position = await _locationService.getCurrentPosition();

      if (position != null && mounted) {
        if (widget.isBusinessOwner) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const BusinessOwnerScaffold(),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => MainScaffold(
                latitude: position.latitude,
                longitude: position.longitude,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        _showError('Konum alınamadı');
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectLocation() {
    // TODO: Navigate to map page for manual location selection
    _showError('Bu özellik yakında eklenecek');
  }

  void _showError(String message) {
    AppNotice.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Location Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Paketleri nerede bulmak\nistersiniz?',
                textAlign: TextAlign.center,
                style: AppTypography.h2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(flex: 3),

              // Use Current Location Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _useCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Mevcut konumumu kullan',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Select Location Button
              TextButton(
                onPressed: _isLoading ? null : _selectLocation,
                child: Text(
                  'Konum seç',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
