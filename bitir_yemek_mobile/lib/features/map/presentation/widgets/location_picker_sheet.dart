import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../core/services/location_service.dart';

/// Edits the search centre and radius; values apply only on confirmation.
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
  late double _radius = widget.initialRadius.clamp(1.0, 50.0);
  bool _loading = false;
  bool _locationUpdated = false;

  Future<void> _useCurrentLocation() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _locationUpdated = true;
        });
      } else {
        AppNotice.warning(
          context,
          'Konum alınamadı. Lütfen konum iznini kontrol edin.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppNotice.warning(context, 'Konum alınamadı. Tekrar deneyebilirsin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResults() =>
      Navigator.of(context).pop((lat: _lat, lng: _lng, radius: _radius));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCC9B9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arama alanın',
                            style: AppTypography.h2.copyWith(
                              fontSize: 26,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Yakınındaki lezzetleri ne kadar uzakta arayalım?',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.inkSoft,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF3E6D9),
                        foregroundColor: AppColors.inkSoft,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EBDD),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEBDACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.radar_rounded,
                                size: 20,
                                color: AppColors.primaryInk,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Arama mesafesi',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_radius.round()} km',
                            style: AppTypography.h2.copyWith(
                              fontSize: 28,
                              color: AppColors.primaryInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seçili konumun çevresindeki alan',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: const Color(0xFFE3CFBA),
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 9,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 20,
                          ),
                          activeTickMarkColor: Colors.transparent,
                          inactiveTickMarkColor: Colors.transparent,
                        ),
                        child: Slider(
                          value: _radius,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '${_radius.round()} km',
                          semanticFormatterCallback: (value) =>
                              '${value.round()} kilometre',
                          onChanged: (value) => setState(() => _radius = value),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1 km',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                          Text(
                            '50 km',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final distance in [1, 5, 10, 25, 50])
                            ChoiceChip(
                              label: Text('$distance km'),
                              selected: _radius.round() == distance,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _radius = distance.toDouble()),
                              backgroundColor: const Color(0xFFFFF9F2),
                              selectedColor: AppColors.primary,
                              side: BorderSide(
                                color: _radius.round() == distance
                                    ? AppColors.primary
                                    : const Color(0xFFE5D3C2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              labelStyle: AppTypography.bodySmall.copyWith(
                                color: _radius.round() == distance
                                    ? Colors.white
                                    : AppColors.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: const Color(0xFFFFF9F2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFEBDACA)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _loading ? null : _useCurrentLocation,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9E4D4),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: _loading
                                ? const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location_rounded,
                                    size: 22,
                                    color: AppColors.primaryInk,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _loading
                                      ? 'Konumun alınıyor…'
                                      : 'Mevcut konumumu kullan',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _locationUpdated
                                      ? 'Arama merkezi güncellendi'
                                      : 'Arama merkezini bulunduğun yere taşı',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _locationUpdated
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            size: 21,
                            color: _locationUpdated
                                ? AppColors.successInk
                                : AppColors.inkSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _showResults,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_rounded, size: 21),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Sonuçları göster',
                            textAlign: TextAlign.center,
                            style: AppTypography.button.copyWith(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
