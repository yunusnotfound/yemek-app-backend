import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../config/theme.dart';

typedef ManualLocation = ({double latitude, double longitude});
typedef _Result = ({String label, ManualLocation point});

/// Bölge araması GPS izni istemez; mevcut cihaz adres çözümleyicisini kullanır.
class ManualLocationPage extends StatefulWidget {
  const ManualLocationPage({super.key});

  @override
  State<ManualLocationPage> createState() => _ManualLocationPageState();
}

class _ManualLocationPageState extends State<ManualLocationPage> {
  final _query = TextEditingController();
  List<_Result> _results = [];
  String? _message;
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<List<_Result>> _findLocations(String query) async {
    final locations = await locationFromAddress('$query, Türkiye');
    final results = <_Result>[];
    for (final location in locations.take(5)) {
      if (!location.latitude.isFinite ||
          !location.longitude.isFinite ||
          location.latitude.abs() > 90 ||
          location.longitude.abs() > 180) {
        continue;
      }
      var label = query;
      try {
        final places = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        ).timeout(const Duration(seconds: 2));
        if (places.isNotEmpty) {
          final place = places.first;
          final parts = [
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ].whereType<String>().where((part) => part.trim().isNotEmpty).toSet();
          if (parts.isNotEmpty) label = parts.join(', ');
        }
      } catch (_) {
        // İleri arama başarılıysa ters adres çözümlemesi seçimi engellemez.
      }
      final point = (
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!results.any((result) => result.point == point)) {
        results.add((label: label, point: point));
      }
    }
    return results;
  }

  Future<void> _search() async {
    if (_loading) return;
    final query = _query.text.trim();
    if (query.length < 3) {
      setState(() => _message = 'İl veya ilçe adını en az 3 karakterle yaz.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _results = [];
      _message = null;
    });
    try {
      final results = await _findLocations(
        query,
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _message =
              'Bölge bulunamadı. İl ve ilçe adını birlikte yazmayı dene.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _message = 'Bölge aranamadı. Bağlantını kontrol edip tekrar dene.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Konum seç')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text('Fırsatları hangi bölgede arayalım?', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'İl, ilçe veya mahalle adını yaz. Konum izni vermen gerekmiyor.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _query,
            readOnly: _loading,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'İl veya ilçe',
              hintText: 'Örn. Kadıköy, İstanbul',
              prefixIcon: Icon(Icons.search_rounded),
              counterText: '',
            ),
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {
              _results = [];
              _message = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _loading ? null : _search,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Bölgeyi ara', textAlign: TextAlign.center),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(_message!, style: AppTypography.bodyMedium),
            ),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Devam etmek için bölgeni seç',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final result in _results)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DecoratedBox(
                  decoration: AppDepth.surface(),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => Navigator.of(
                        context,
                      ).pop<ManualLocation>(result.point),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.primaryInk,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                result.label,
                                style: AppTypography.bodyLarge,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
