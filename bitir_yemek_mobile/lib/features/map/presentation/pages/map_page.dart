import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/presentation/pages/business_detail_page.dart';
import '../../data/datasources/map_remote_datasource.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../widgets/business_map_card.dart';
import '../widgets/map_filter_bar.dart';
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
  // Marka renkleri (badge için teal — AppColors.primary turuncu olduğundan kullanılmıyor).
  static const int _tealColor = 0xFF0E5A4F;
  static const int _iconSize = 120;

  MapboxMap? _mapController;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _currentPolyline;
  Cancelable? _tapCancelable;

  final Map<String, BusinessModel> _annotationIdToBusiness = {};
  final List<PointAnnotation> _businessAnnotations = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedCategoryId; // null = Tümü
  bool _collectNow = false;

  bool _markersLoaded = false;
  bool _loadingMarkers = false;
  bool _renderPending = false;
  bool _cameraFitted = false;

  @override
  void dispose() {
    _tapCancelable?.cancel();
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

  Future<void> _initAnnotationManagers() async {
    if (_mapController == null) return;
    try {
      _pointAnnotationManager = await _mapController!.annotations
          .createPointAnnotationManager();
      _polylineAnnotationManager = await _mapController!.annotations
          .createPolylineAnnotationManager();

      _tapCancelable = _pointAnnotationManager!.tapEvents(
        onTap: (PointAnnotation annotation) => _onAnnotationTapped(annotation),
      );

      _loadMarkers();
    } catch (e) {
      debugPrint('Error creating annotation manager: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Business markers (PointAnnotation)
  // ---------------------------------------------------------------------------

  List<BusinessModel> get _allBusinesses {
    final state = context.read<MapBloc>().state;
    if (state is MapLoaded) return state.businesses;
    if (state is MapError) return state.businesses;
    return const [];
  }

  List<BusinessModel> get _visibleBusinesses {
    Iterable<BusinessModel> list = _allBusinesses;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((b) => b.name.toLowerCase().contains(q));
    }
    if (_selectedCategoryId != null) {
      list = list.where((b) => b.category.id == _selectedCategoryId);
    }
    if (_collectNow) {
      list = list.where((b) => b.availableNow);
    }
    return list.toList();
  }

  /// Yakındaki işletmelerden tekilleştirilmiş, ada göre sıralı kategori listesi.
  List<({int id, String name})> get _categoryOptions {
    final seen = <int, String>{};
    for (final b in _allBusinesses) {
      seen[b.category.id] = b.category.name;
    }
    final list = seen.entries
        .map((e) => (id: e.key, name: e.value))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// İlk yüklemede tüm marker'ları kurar ve kamerayı çerçeveler.
  Future<void> _loadMarkers() async {
    if (_pointAnnotationManager == null || _markersLoaded) return;
    final state = context.read<MapBloc>().state;
    if (state is! MapLoaded || state.businesses.isEmpty) return;

    _markersLoaded = true;
    await _applyMarkers();

    if (!_cameraFitted) {
      _cameraFitted = true;
      await _fitCameraToMarkers(state.businesses);
    }
  }

  /// Güncel filtrelere göre marker'ları yeniden çizer.
  /// Eşzamanlı çağrılar coalesce edilir; son istenen durum garanti edilir.
  Future<void> _applyMarkers() async {
    if (_loadingMarkers) {
      _renderPending = true;
      return;
    }
    _loadingMarkers = true;
    try {
      do {
        _renderPending = false;
        await _renderOnce(_visibleBusinesses);
      } while (_renderPending);
    } finally {
      _loadingMarkers = false;
    }
  }

  /// Verilen işletmeler için marker'ları (logo + rozet) oluşturur.
  /// Önce mevcut işletme marker'larını ve kullanıcı konumunu temizler, yeniden çizer.
  Future<void> _renderOnce(List<BusinessModel> businesses) async {
    final manager = _pointAnnotationManager;
    if (manager == null) return;

    await manager.deleteAll();
    _businessAnnotations.clear();
    _annotationIdToBusiness.clear();

    // Kullanıcı konumu marker'ı.
    await _addCurrentLocationMarker();

    // Ağ logoları paralel yüklenir; render + create sırayla yapılır.
    final logos = await Future.wait(
      businesses.map((b) => _loadNetworkImage(b.imageUrl)),
    );
    for (var i = 0; i < businesses.length; i++) {
      final business = businesses[i];
      try {
        final iconBytes = await _createLogoMarkerIcon(business, logos[i]);
        final annotation = await manager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(business.longitude, business.latitude),
            ),
            image: iconBytes,
            iconSize: 0.85,
            iconAnchor: IconAnchor.CENTER,
          ),
        );
        _businessAnnotations.add(annotation);
        _annotationIdToBusiness[annotation.id] = business;
      } catch (e) {
        debugPrint('Error creating marker for ${business.name}: $e');
      }
    }
  }

  Future<void> _fitCameraToMarkers(List<BusinessModel> businesses) async {
    if (_mapController == null || businesses.isEmpty) return;
    try {
      final points = <Point>[
        Point(coordinates: Position(widget.longitude, widget.latitude)),
        ...businesses.map(
          (b) => Point(coordinates: Position(b.longitude, b.latitude)),
        ),
      ];
      final camera = await _mapController!.cameraForCoordinatesPadding(
        points,
        CameraOptions(),
        MbxEdgeInsets(top: 140, left: 60, bottom: 200, right: 60),
        16.0, // maxZoom — tek işletme kullanıcıya çok yakınsa aşırı zoom'u engeller
        null,
      );
      await _mapController!.flyTo(camera, MapAnimationOptions(duration: 700));
    } catch (e) {
      debugPrint('Error fitting camera: $e');
    }
  }

  void _onAnnotationTapped(PointAnnotation annotation) {
    final business = _annotationIdToBusiness[annotation.id];
    if (business == null) return; // kullanıcı konumu marker'ı vb.

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

  // ---------------------------------------------------------------------------
  // Icon rendering
  // ---------------------------------------------------------------------------

  /// İşletme logosunu beyaz daire içine çizer; köşeye teal paket-sayısı rozeti basar.
  /// Logo yoksa baş-harf fallback kullanır. PNG bayt döndürür (PointAnnotation için).
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
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius - 3)),
      );
      final src = _coverSrcRect(logo);
      canvas.drawImageRect(
        logo,
        src,
        Rect.fromCircle(center: center, radius: radius - 3),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
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
      tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
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
      const badgeCenter = Offset(size - 30, 30);
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
      tp.paint(canvas, badgeCenter.translate(-tp.width / 2, -tp.height / 2));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_iconSize, _iconSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Logoyu kareye "cover" şeklinde sığdırmak için kaynak dikdörtgeni hesaplar.
  Rect _coverSrcRect(ui.Image image) {
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
    const center = Offset(size / 2, size / 2);

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

  void _onMapTap(MapContentGestureContext _) {
    final state = context.read<MapBloc>().state;
    if (state is MapLoaded && state.selectedBusiness != null) {
      context.read<MapBloc>().add(const ClearSelection());
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _applyMarkers();
  }

  void _onCategorySelected(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    _applyMarkers();
  }

  void _onCollectNowChanged(bool value) {
    setState(() => _collectNow = value);
    _applyMarkers();
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailPage(
          businessId: business.id,
          businessName: business.name,
        ),
      ),
    );
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
            if (!_markersLoaded) {
              _loadMarkers();
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

              // Filter bar (Şimdi Al + kategoriler)
              if (state is MapLoaded && state.businesses.isNotEmpty)
                Positioned(
                  top: MediaQuery.of(context).padding.top + AppSpacing.sm + 60,
                  left: 0,
                  right: 0,
                  child: MapFilterBar(
                    categories: _categoryOptions,
                    selectedCategoryId: _selectedCategoryId,
                    collectNow: _collectNow,
                    onCategorySelected: _onCategorySelected,
                    onCollectNowChanged: _onCollectNowChanged,
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
                    package: state.selectedPackage,
                    packageLoading: state.packageLoading,
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
      // Genişletilmiş TGTG kartının üstünde kal.
      return 430 + MediaQuery.of(context).padding.bottom;
    }
    return 110 + MediaQuery.of(context).padding.bottom;
  }
}
