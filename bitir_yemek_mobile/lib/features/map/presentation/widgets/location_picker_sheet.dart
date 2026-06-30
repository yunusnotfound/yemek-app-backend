import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../core/services/location_service.dart';

/// TGTG tarzı konum seçici panel. Mesafe (yarıçap) slider'ı ve
/// "Mevcut konumumu kullan" sunar; "Sonuçları göster" ile seçimi
/// `(lat, lng, radius)` record olarak [Navigator.pop] eder.
class LocationPickerSheet extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialRadius;

  const LocationPickerSheet({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.initialRadius,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late double _lat = widget.initialLat;
  late double _lng = widget.initialLng;
  late double _radius = widget.initialRadius;
  String _label = 'Mevcut konum';
  bool _loading = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loading = true);
    final pos = await LocationService().getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _label = 'Mevcut konum';
      });
    } else {
      _toast('Konum alınamadı. Lütfen konum iznini kontrol edin.');
    }
    setState(() => _loading = false);
  }

  void _showResults() {
    Navigator.of(context).pop((lat: _lat, lng: _lng, radius: _radius));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // Klavye açılınca panel yukarı kalksın.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Başlık + kapat
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Konumu seç',
                      style: AppTypography.h3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(
                      Icons.close,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Mesafe slider'ı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mesafe seç', style: AppTypography.bodyMedium),
                  Text(
                    '${_radius.round()} km',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radius.clamp(1, 50),
                min: 1,
                max: 50,
                divisions: 49,
                activeColor: AppColors.primary,
                label: '${_radius.round()} km',
                onChanged: (v) => setState(() => _radius = v),
              ),
              const SizedBox(height: AppSpacing.md),

              // Mevcut konumumu kullan
              Center(
                child: TextButton.icon(
                  onPressed: _loading ? null : _useCurrentLocation,
                  icon: const Icon(Icons.near_me, size: 18),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  label: const Text('Mevcut konumumu kullan'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Seçili konum etiketi
              Center(
                child: Text(
                  'Seçili: $_label',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Sonuçları göster
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _showResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sonuçları göster',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
