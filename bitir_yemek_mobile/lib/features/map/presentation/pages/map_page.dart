import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/datasources/map_remote_datasource.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../widgets/business_map_card.dart';
import '../widgets/map_search_bar.dart';

class MapPage extends StatelessWidget {
  final double latitude;
  final double longitude;
  final DioClient dioClient;

  const MapPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.dioClient,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          MapBloc(
            repository: MapRepositoryImpl(
              remoteDataSource: MapRemoteDataSource(dioClient: dioClient),
            ),
          )..add(
            LoadBusinessesForMap(
              latitude: latitude,
              longitude: longitude,
              radius: 10.0,
            ),
          ),
      child: _MapPageContent(latitude: latitude, longitude: longitude),
    );
  }
}

class _MapPageContent extends StatefulWidget {
  final double latitude;
  final double longitude;

  const _MapPageContent({required this.latitude, required this.longitude});

  @override
  State<_MapPageContent> createState() => _MapPageContentState();
}

class _MapPageContentState extends State<_MapPageContent> {
  // Style source/layer kimlikleri.
  static const String _sourceId = 'businesses-source';
  static const String _unclusteredLayerId = 'businesses-unclustered';
  static const String _clusterLayerId = 'businesses-clusters';
  static const String _clusterCountLayerId = 'businesses-cluster-count';

  // Marka renkleri (badge/cluster için teal — AppColors.primary turuncu olduğundan kullanılmıyor).
  static const int _tealColor = 0xFF0E5A4F;

  MapboxMap? _mapController;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _currentPolyline;

  final Map<String, BusinessModel> _businessById = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _styleLoaded = false;
  bool _layersAdded = false;
  bool _settingUp = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Map lifecycle
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapboxMap controller) {
    _mapController = controller;
    // Harita alt kısmındaki "mapbox" logosunu ve (i) attribution butonunu gizle.
    controller.logo.updateSettings(LogoSettings(enabled: false));
    controller.attribution.updateSettings(AttributionSettings(enabled: false));
    // Üst kısımdaki ölçek çubuğunu (scale bar) gizle.
    controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    _initAnnotationManagers();
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    _styleLoaded = true;
    _setupMarkers();
  }

  Future<void> _initAnnotationManagers() async {
    if (_mapController == null) return;
    try {
      _pointAnnotationManager = await _mapController!.annotations
          .createPointAnnotationManager();
      _polylineAnnotationManager = await _mapController!.annotations
          .createPolylineAnnotationManager();
      await _addCurrentLocationMarker();
    } catch (e) {
      debugPrint('Error creating annotation manager: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Business markers — GeoJSON source + clustering
  // ---------------------------------------------------------------------------

  List<BusinessModel> get _visibleBusinesses {
    final state = context.read<MapBloc>().state;
    final all = state is MapLoaded
        ? state.businesses
        : (state is MapError ? state.businesses : const <BusinessModel>[]);
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _setupMarkers() async {
    if (_mapController == null || !_styleLoaded || _layersAdded || _settingUp) {
      return;
    }
    final state = context.read<MapBloc>().state;
    if (state is! MapLoaded || state.businesses.isEmpty) return;

    _settingUp = true;
    try {
      final style = _mapController!.style;
      _businessById.clear();

      // 1) Her işletme için logolu (badge'li) marker görselini kaydet.
      //    Ağ logoları paralel yüklenir; render + kayıt sırayla yapılır.
      final logos = await Future.wait(
        state.businesses.map((b) => _loadNetworkImage(b.imageUrl)),
      );
      for (var i = 0; i < state.businesses.length; i++) {
        final business = state.businesses[i];
        _businessById[business.id] = business;
        try {
          final bytes = await _createLogoMarkerIcon(business, logos[i]);
          await style.addStyleImage(
            'marker_${business.id}',
            2.5,
            MbxImage(width: _iconSize, height: _iconSize, data: bytes),
            false,
            const [],
            const [],
            null,
          );
        } catch (e) {
          debugPrint('Error creating marker for ${business.name}: $e');
        }
      }

      // 2) Cluster özellikli GeoJSON source ekle.
      if (!await style.styleSourceExists(_sourceId)) {
        final sourceJson = jsonEncode({
          'type': 'geojson',
          'cluster': true,
          'clusterRadius': 50,
          'clusterMaxZoom': 14,
          'data': _featureCollection(_visibleBusinesses),
        });
        await style.addStyleSource(_sourceId, sourceJson);
      }

      // 3) Katmanlar: kümelenmemiş semboller + küme dairesi + küme sayısı.
      if (!await style.styleLayerExists(_unclusteredLayerId)) {
        await style.addStyleLayer(
          jsonEncode({
            'id': _unclusteredLayerId,
            'type': 'symbol',
            'source': _sourceId,
            'slot': 'top',
            'filter': ['!', ['has', 'point_count']],
            'layout': {
              'icon-image': ['get', 'icon'],
              'icon-size': 1.0,
              'icon-allow-overlap': true,
              'icon-anchor': 'center',
            },
          }),
          null,
        );
      }
      if (!await style.styleLayerExists(_clusterLayerId)) {
        await style.addStyleLayer(
          jsonEncode({
            'id': _clusterLayerId,
            'type': 'circle',
            'source': _sourceId,
            'slot': 'top',
            'filter': ['has', 'point_count'],
            'paint': {
              'circle-color': '#0E5A4F',
              'circle-radius': [
                'step',
                ['get', 'point_count'],
                20,
                10,
                26,
                30,
                32,
              ],
              'circle-stroke-width': 4,
              'circle-stroke-color': '#FFFFFF',
            },
          }),
          null,
        );
      }
      if (!await style.styleLayerExists(_clusterCountLayerId)) {
        await style.addStyleLayer(
          jsonEncode({
            'id': _clusterCountLayerId,
            'type': 'symbol',
            'source': _sourceId,
            'slot': 'top',
            'filter': ['has', 'point_count'],
            'layout': {
              'text-field': ['get', 'point_count_abbreviated'],
              'text-size': 15,
              'text-allow-overlap': true,
            },
            'paint': {'text-color': '#FFFFFF'},
          }),
          null,
        );
      }

      _layersAdded = true;
    } catch (e) {
      debugPrint('Error setting up markers: $e');
    } finally {
      _settingUp = false;
    }
  }

  /// Arama sonucu değişince sadece source verisini güncelle (görselleri tekrar kurmadan).
  Future<void> _refreshSourceData() async {
    if (_mapController == null || !_layersAdded) return;
    try {
      await _mapController!.style.setStyleSourceProperty(
        _sourceId,
        'data',
        _featureCollection(_visibleBusinesses),
      );
    } catch (e) {
      debugPrint('Error refreshing source data: $e');
    }
  }

  Map<String, dynamic> _featureCollection(List<BusinessModel> list) {
    return {
      'type': 'FeatureCollection',
      'features': list
          .map(
            (b) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [b.longitude, b.latitude],
              },
              'properties': {
                'businessId': b.id,
                'icon': 'marker_${b.id}',
                'packageCount': b.packageCount,
              },
            },
          )
          .toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Icon rendering
  // ---------------------------------------------------------------------------

  static const int _iconSize = 120;

  /// İşletme logosunu beyaz daire içine çizer; köşeye teal paket-sayısı rozeti basar.
  /// Logo yoksa baş-harf fallback kullanır. Ham RGBA bayt döndürür (MbxImage için).
  Future<Uint8List> _createLogoMarkerIcon(
    BusinessModel business,
    ui.Image? logo,
  ) async {
    const double size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    const center = Offset(size / 2, size / 2);
    const radius = 44.0;

    // Gölge.
    canvas.drawCircle(
      center.translate(0, 3),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Beyaz daire taban.
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    if (logo != null) {
      // Logoyu daireye (cover) çiz.
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius - 3)),
      );
      final src = _coverSrcRect(logo, radius * 2);
      canvas.drawImageRect(
        logo,
        src,
        Rect.fromCircle(center: center, radius: radius - 3),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      // Fallback: marka renkli daire + baş harf.
      canvas.drawCircle(
        center,
        radius - 3,
        Paint()..color = AppColors.primary,
      );
      final letter = business.name.isNotEmpty ? business.name[0] : '?';
      final tp = TextPainter(
        text: TextSpan(
          text: letter.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            fontFamily: 'Korolev',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        center.translate(-tp.width / 2, -tp.height / 2),
      );
    }

    // Beyaz kenarlık halkası.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Paket-sayısı rozeti (sağ üst).
    if (business.packageCount > 0) {
      final badgeCenter = const Offset(size - 30, 30);
      const badgeRadius = 22.0;
      canvas.drawCircle(
        badgeCenter,
        badgeRadius + 2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        badgeCenter,
        badgeRadius,
        Paint()..color = const Color(_tealColor),
      );
      final countText = business.packageCount > 99
          ? '99+'
          : '${business.packageCount}';
      final tp = TextPainter(
        text: TextSpan(
          text: countText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        badgeCenter.translate(-tp.width / 2, -tp.height / 2),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_iconSize, _iconSize);
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    return byteData!.buffer.asUint8List();
  }

  /// Logoyu kareye "cover" şeklinde sığdırmak için kaynak dikdörtgeni hesaplar.
  Rect _coverSrcRect(ui.Image image, double targetSize) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final side = w < h ? w : h;
    final dx = (w - side) / 2;
    final dy = (h - side) / 2;
    return Rect.fromLTWH(dx, dy, side, side);
  }

  Future<ui.Image?> _loadNetworkImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final completer = Completer<ui.Image?>();
      final stream = NetworkImage(url).resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (e, st) {
          if (!completer.isCompleted) completer.complete(null);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Current location marker
  // ---------------------------------------------------------------------------

  Future<void> _addCurrentLocationMarker() async {
    if (_pointAnnotationManager == null) return;
    try {
      final iconBytes = await _createCurrentLocationIcon();
      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(widget.longitude, widget.latitude),
          ),
          image: iconBytes,
          iconSize: 0.6,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (e) {
      debugPrint('Error creating current location marker: $e');
    }
  }

  Future<Uint8List> _createCurrentLocationIcon() async {
    const size = 200.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final center = const Offset(size / 2, size / 2);

    final pulsePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A90D9).withValues(alpha: 0.25),
          const Color(0xFF4A90D9).withValues(alpha: 0.0),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size / 2));
    canvas.drawCircle(center, size / 2, pulsePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, size / 4.5, borderPaint);

    final innerPaint = Paint()..color = const Color(0xFF4A90D9);
    canvas.drawCircle(center, size / 4.5, innerPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, size / 14, dotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ---------------------------------------------------------------------------
  // Route polyline
  // ---------------------------------------------------------------------------

  Future<void> _drawRoutePolyline(List<dynamic> coordinates) async {
    if (_polylineAnnotationManager == null) return;
    if (_currentPolyline != null) {
      await _polylineAnnotationManager!.delete(_currentPolyline!);
      _currentPolyline = null;
    }
    final positions = coordinates.map((coord) {
      final list = coord as List<dynamic>;
      return Position(list[0] as double, list[1] as double);
    }).toList();
    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: positions),
      lineColor: AppColors.primary.toARGB32(),
      lineWidth: 5.0,
    );
    _currentPolyline = await _polylineAnnotationManager!.create(options);
  }

  Future<void> _clearRoutePolyline() async {
    if (_polylineAnnotationManager != null && _currentPolyline != null) {
      await _polylineAnnotationManager!.delete(_currentPolyline!);
      _currentPolyline = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Interactions
  // ---------------------------------------------------------------------------

  Future<void> _onMapTap(MapContentGestureContext gestureContext) async {
    if (_mapController == null || !_layersAdded) return;

    List<QueriedRenderedFeature?> features;
    try {
      features = await _mapController!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(
          gestureContext.touchPosition,
        ),
        RenderedQueryOptions(
          layerIds: [_unclusteredLayerId, _clusterLayerId],
          filter: null,
        ),
      );
    } catch (e) {
      debugPrint('queryRenderedFeatures error: $e');
      return;
    }

    Map<String?, Object?>? hit;
    for (final f in features) {
      if (f != null) {
        hit = f.queriedFeature.feature;
        break;
      }
    }

    if (hit == null) {
      _clearSelectionIfAny();
      return;
    }

    final props = hit['properties'];
    final propMap = props is Map ? props : const {};

    if (propMap['cluster'] == true || propMap.containsKey('point_count')) {
      await _zoomToCluster(hit);
      return;
    }

    final businessId = propMap['businessId'];
    final business = _businessById[businessId];
    if (business == null) {
      _clearSelectionIfAny();
      return;
    }

    if (!mounted) return;
    context.read<MapBloc>().add(SelectBusiness(business: business));
    context.read<MapBloc>().add(
      RequestDirections(
        originLat: widget.latitude,
        originLng: widget.longitude,
        destLat: business.latitude,
        destLng: business.longitude,
      ),
    );
  }

  Future<void> _zoomToCluster(Map<String?, Object?> clusterFeature) async {
    try {
      final ext = await _mapController!.getGeoJsonClusterExpansionZoom(
        _sourceId,
        clusterFeature,
      );
      final zoom = double.tryParse(ext.value ?? '') ?? 14.0;
      final geom = clusterFeature['geometry'];
      final coords = geom is Map ? geom['coordinates'] as List? : null;
      if (coords != null && coords.length >= 2) {
        await _mapController!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                (coords[0] as num).toDouble(),
                (coords[1] as num).toDouble(),
              ),
            ),
            zoom: zoom + 0.5,
          ),
          MapAnimationOptions(duration: 600),
        );
      }
    } catch (e) {
      debugPrint('Error zooming to cluster: $e');
    }
  }

  void _clearSelectionIfAny() {
    final state = context.read<MapBloc>().state;
    if (state is MapLoaded && state.selectedBusiness != null) {
      context.read<MapBloc>().add(const ClearSelection());
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _refreshSourceData();
  }

  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;
    await _mapController!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(widget.longitude, widget.latitude),
        ),
        zoom: 14.0,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  void _onCloseCard() {
    context.read<MapBloc>().add(const ClearSelection());
  }

  void _onNavigate(BusinessModel business) async {
    final googleMapsUrl =
        'comgooglemaps://?daddr=${business.latitude},${business.longitude}&directionsmode=driving';
    final appleMapsUrl =
        'maps://maps.apple.com/?daddr=${business.latitude},${business.longitude}&dirflg=d';
    final webGoogleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${business.latitude},${business.longitude}&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl));
    } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(Uri.parse(appleMapsUrl));
    } else if (await canLaunchUrl(Uri.parse(webGoogleMapsUrl))) {
      await launchUrl(
        Uri.parse(webGoogleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _onViewDetails(BusinessModel business) {
    debugPrint('View details tapped for ${business.name}');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  int get _totalPackages =>
      _visibleBusinesses.fold(0, (sum, b) => sum + b.packageCount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state is MapLoaded) {
            if (!_layersAdded) {
              _setupMarkers();
            }
            if (state.directions != null) {
              final geometry = state.directions!['geometry'] as List<dynamic>?;
              if (geometry != null) {
                _drawRoutePolyline(geometry);
              }
            } else {
              _clearRoutePolyline();
            }
          }
        },
        builder: (context, state) {
          final hasSelection =
              state is MapLoaded && state.selectedBusiness != null;
          return Stack(
            children: [
              Positioned.fill(
                child: MapWidget(
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(widget.longitude, widget.latitude),
                    ),
                    zoom: 13.0,
                  ),
                  styleUri: MapboxStyles.STANDARD,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedListener: _onStyleLoaded,
                  onTapListener: _onMapTap,
                ),
              ),

              // Search bar
              Positioned(
                top: MediaQuery.of(context).padding.top + AppSpacing.sm,
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                child: MapSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onLocationTap: _goToMyLocation,
                ),
              ),

              // Loading overlay
              if (state is MapLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),

              // Error overlay
              if (state is MapError)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 72,
                  left: AppSpacing.screenPadding,
                  right: AppSpacing.screenPadding,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            state.message,
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            context.read<MapBloc>().add(
                              LoadBusinessesForMap(
                                latitude: widget.latitude,
                                longitude: widget.longitude,
                                radius: 10.0,
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

              // My Location FAB
              Positioned(
                right: AppSpacing.screenPadding,
                bottom: _getFabBottomOffset(state),
                child: FloatingActionButton(
                  onPressed: _goToMyLocation,
                  backgroundColor: AppColors.surface,
                  child: const Icon(
                    Icons.my_location,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // Business card when selected
              if (hasSelection)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: BusinessMapCard(
                    business: state.selectedBusiness!,
                    directions: state.directions,
                    onClose: _onCloseCard,
                    onNavigate: () => _onNavigate(state.selectedBusiness!),
                    onViewDetails: () =>
                        _onViewDetails(state.selectedBusiness!),
                  ),
                ),

              // Bottom "N Sürpriz Paket" counter (hidden while a card is open)
              if (!hasSelection && state is MapLoaded)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildCounterBar(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCounterBar() {
    final count = _totalPackages;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            count == 1 ? '1 Sürpriz Paket' : '$count Sürpriz Paket',
            style: AppTypography.h3,
          ),
        ],
      ),
    );
  }

  double _getFabBottomOffset(MapState state) {
    if (state is MapLoaded && state.selectedBusiness != null) {
      return 260;
    }
    // Üstte sayaç şeridi var; FAB onun üstünde kalsın.
    return 110 + MediaQuery.of(context).padding.bottom;
  }
}
