import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/package_model.dart';
import '../../../home/presentation/pages/business_detail_page.dart';
import '../../../home/presentation/pages/package_detail_page.dart';
import '../widgets/map_packages_sheet.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../services/map_marker_icons.dart';
import '../services/marker_load_queue.dart';
import '../widgets/business_map_card.dart';
import '../widgets/location_picker_sheet.dart';
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
    // MapBloc artık MainScaffold'da sağlanıyor. Bu sayfa Mapbox PlatformView'i
    // yüzünden IndexedStack dışında tutulduğundan sekmeye her girişte baştan
    // kurulur; bloc'u burada yaratmak her girişte /maps/nearby + /packages
    // çiftini yeniden çağırıyordu. İlk yükleme initState'te; sonraki sessiz
    // güncellemeler MainScaffold'daki CatalogRefresh ile yapılır.
    return _MapPageContent(latitude: latitude, longitude: longitude);
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
  final MapMarkerIcons _markerIcons = MapMarkerIcons();
  final MarkerLoadQueue<BusinessModel> _logoQueue = MarkerLoadQueue();
  final Map<String, PointAnnotation> _businessIdToAnnotation = {};
  int _markerGeneration = 0;

  MapboxMap? _mapController;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _currentPolyline;
  Cancelable? _tapCancelable;

  final Map<String, BusinessModel> _annotationIdToBusiness = {};
  final List<PointAnnotation> _businessAnnotations = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  int? _selectedCategoryId; // null = Tümü
  bool _collectNow = false;

  bool _markersLoaded = false;
  List<BusinessModel> _lastMarkerBusinesses = const [];
  bool _loadingMarkers = false;
  bool _renderPending = false;
  bool _cameraFitted = false;

  // Aktif harita merkezi/yarıçapı. Konum seçici bir override set edene kadar
  // widget'tan gelen ilk konum kullanılır. (Nullable + getter; `late` yok ki
  // hot reload'da LateInitializationError olmasın.)
  double? _latOverride;
  double? _lngOverride;
  double get _lat => _latOverride ?? widget.latitude;
  double get _lng => _lngOverride ?? widget.longitude;
  double _radius = 10.0;

  @override
  void initState() {
    super.initState();
    // Bloc sekmeler arası paylaşıldığı için veri zaten yüklenmiş olabilir;
    // yalnızca hiç yüklenmemişse ağa çık. Sonraki yenilemeleri CatalogRefresh
    // birleştirir; marker'lar ve kamera istek sırasında yerinde kalır.
    final bloc = context.read<MapBloc>();
    if (bloc.state is MapInitial) {
      bloc.add(
        LoadBusinessesForMap(latitude: _lat, longitude: _lng, radius: _radius),
      );
    }
  }

  @override
  void dispose() {
    _markerGeneration++;
    _logoQueue.cancel();
    _searchDebounce?.cancel();
    _tapCancelable?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Map lifecycle
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapboxMap controller) {
    _mapController = controller;
    // Harita üzerindeki Mapbox logosunu ve mavi bilgi düğmesini gizle.
    controller.logo.updateSettings(LogoSettings(enabled: false));
    controller.attribution.updateSettings(AttributionSettings(enabled: false));
    // Üst kısımdaki ölçek çubuğunu (scale bar) gizle.
    controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    _initAnnotationManagers();
  }

  Future<void> _initAnnotationManagers() async {
    if (_mapController == null) return;
    try {
      final controller = _mapController!;
      final pointManager = await controller.annotations
          .createPointAnnotationManager();
      if (!mounted || !identical(controller, _mapController)) return;
      _pointAnnotationManager = pointManager;
      final polylineManager = await controller.annotations
          .createPolylineAnnotationManager();
      if (!mounted || !identical(controller, _mapController)) return;
      _polylineAnnotationManager = polylineManager;

      _tapCancelable = _pointAnnotationManager!.tapEvents(
        onTap: (PointAnnotation annotation) => _onAnnotationTapped(annotation),
      );

      _loadMarkers();
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating annotation manager: $e');
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
    final list = seen.entries.map((e) => (id: e.key, name: e.value)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// İlk yüklemede tüm marker'ları kurar ve kamerayı çerçeveler.
  Future<void> _loadMarkers() async {
    if (!mounted || _pointAnnotationManager == null || _markersLoaded) return;
    final state = context.read<MapBloc>().state;
    if (state is! MapLoaded) return;

    _markersLoaded = true;
    await _applyMarkers();

    if (mounted && !_cameraFitted && _allBusinesses.isNotEmpty) {
      _cameraFitted = true;
      await _fitCameraToMarkers(_allBusinesses);
    }
  }

  /// Rebuild only the current view. Optional logo requests never block markers.
  Future<void> _applyMarkers() async {
    if (!mounted) return;
    _markerGeneration++;
    _logoQueue.cancel();
    if (_loadingMarkers) {
      _renderPending = true;
      return;
    }
    _loadingMarkers = true;
    try {
      do {
        _renderPending = false;
        await _renderOnce(_visibleBusinesses, _markerGeneration);
      } while (mounted && _renderPending);
    } catch (error) {
      if (kDebugMode) debugPrint('Error creating markers: $error');
    } finally {
      _loadingMarkers = false;
    }
  }

  bool _isCurrentMarkerRender(int generation, PointAnnotationManager manager) =>
      mounted &&
      generation == _markerGeneration &&
      identical(manager, _pointAnnotationManager);

  Future<void> _renderOnce(
    List<BusinessModel> businesses,
    int generation,
  ) async {
    final manager = _pointAnnotationManager;
    if (manager == null || !_isCurrentMarkerRender(generation, manager)) return;

    await manager.deleteAll();
    if (!_isCurrentMarkerRender(generation, manager)) return;
    _businessAnnotations.clear();
    _annotationIdToBusiness.clear();
    _businessIdToAnnotation.clear();
    await _addCurrentLocationMarker(manager, generation);

    final needingLogos = <BusinessModel>[];
    // Small platform batches let markers appear progressively on older phones.
    // Every initial icon is local: one slow logo cannot hide all businesses.
    const batchSize = 24;
    for (var offset = 0; offset < businesses.length; offset += batchSize) {
      final batch = businesses.skip(offset).take(batchSize).toList();
      final options = <PointAnnotationOptions>[];
      for (final business in batch) {
        if (!_isCurrentMarkerRender(generation, manager)) return;
        final cached = _markerIcons.cached(business);
        final bytes = cached ?? await _markerIcons.placeholder(business);
        if (cached == null && (business.imageUrl?.isNotEmpty ?? false)) {
          needingLogos.add(business);
        }
        options.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(business.longitude, business.latitude),
            ),
            image: bytes,
            iconSize: 0.72,
            iconAnchor: IconAnchor.CENTER,
          ),
        );
      }
      if (!_isCurrentMarkerRender(generation, manager)) return;
      final annotations = await manager.createMulti(options);
      if (!_isCurrentMarkerRender(generation, manager)) return;
      for (var i = 0; i < annotations.length; i++) {
        final annotation = annotations[i];
        if (annotation == null) continue;
        _businessAnnotations.add(annotation);
        _annotationIdToBusiness[annotation.id] = batch[i];
        _businessIdToAnnotation[batch[i].id] = annotation;
      }
      await Future<void>.delayed(Duration.zero);
    }
    if (!_isCurrentMarkerRender(generation, manager)) return;
    // At most four downloads/decodes/updates are active, even when a filter
    // changes while the previous view still has requests in flight.
    _logoQueue.replace(needingLogos, (business, isCurrent) async {
      if (!isCurrent() || !_isCurrentMarkerRender(generation, manager)) return;
      final bytes = await _markerIcons.logo(business);
      if (bytes == null ||
          !isCurrent() ||
          !_isCurrentMarkerRender(generation, manager)) {
        return;
      }
      final annotation = _businessIdToAnnotation[business.id];
      if (annotation == null) return;
      annotation.image = bytes;
      await manager.update(annotation);
    });
  }

  Future<void> _fitCameraToMarkers(List<BusinessModel> businesses) async {
    if (_mapController == null || businesses.isEmpty) return;
    try {
      final points = <Point>[
        Point(coordinates: Position(_lng, _lat)),
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
      if (kDebugMode) debugPrint('Error fitting camera: $e');
    }
  }

  void _onAnnotationTapped(PointAnnotation annotation) {
    if (!mounted) return;
    final business = _annotationIdToBusiness[annotation.id];
    if (business == null) return; // kullanıcı konumu marker'ı vb.
    final current = context.read<MapBloc>().state;
    if (current is MapLoaded && current.selectedBusiness?.id == business.id) {
      return;
    }

    context.read<MapBloc>().add(SelectBusiness(business: business));
    context.read<MapBloc>().add(
      RequestDirections(
        originLat: _lat,
        originLng: _lng,
        destLat: business.latitude,
        destLng: business.longitude,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Current location marker
  // ---------------------------------------------------------------------------

  Future<void> _addCurrentLocationMarker(
    PointAnnotationManager manager,
    int generation,
  ) async {
    try {
      final iconBytes = await _markerIcons.currentLocation();
      if (!_isCurrentMarkerRender(generation, manager)) return;
      await manager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(_lng, _lat)),
          image: iconBytes,
          // 300px raster * 0.55 -> ekranda ~165px (eskiden 200 * 0.6 = 120).
          iconSize: 0.55,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating current location marker: $e');
    }
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
    // Boş alana (haritaya) dokununca arama çubuğunun odağını/klavyeyi bırak.
    FocusScope.of(context).unfocus();
    final state = context.read<MapBloc>().state;
    if (state is MapLoaded && state.selectedBusiness != null) {
      context.read<MapBloc>().add(const ClearSelection());
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _markerGeneration++;
    _logoQueue.cancel();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), _applyMarkers);
  }

  void _onCategorySelected(int? categoryId) {
    _searchDebounce?.cancel();
    setState(() => _selectedCategoryId = categoryId);
    _applyMarkers();
  }

  void _onCollectNowChanged(bool value) {
    _searchDebounce?.cancel();
    setState(() => _collectNow = value);
    _applyMarkers();
  }

  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;
    await _mapController!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(_lng, _lat)),
        zoom: 14.0,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  /// Konum seçici paneli açar; sonuç dönerse haritayı yeni merkez/yarıçapa
  /// göre yeniden yükler (marker + kamera + paketler yenilenir).
  Future<void> _openLocationPicker() async {
    FocusScope.of(context).unfocus();
    final result =
        await showModalBottomSheet<({double lat, double lng, double radius})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: const Color(0xFFFFF9F2),
          useSafeArea: true,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) => LocationPickerSheet(
            initialLat: _lat,
            initialLng: _lng,
            initialRadius: _radius,
          ),
        );
    if (result == null || !mounted) return;

    setState(() {
      _latOverride = result.lat;
      _lngOverride = result.lng;
      _radius = result.radius;
    });

    // Marker/kamera yeniden çizilsin diye gate flag'lerini sıfırla.
    _markerGeneration++;
    _logoQueue.cancel();
    _searchDebounce?.cancel();
    _markersLoaded = false;
    _cameraFitted = false;
    _annotationIdToBusiness.clear();
    _businessAnnotations.clear();

    context.read<MapBloc>().add(
      LoadBusinessesForMap(latitude: _lat, longitude: _lng, radius: _radius),
    );

    // İşletme bulunsa _fitCameraToMarkers zaten çerçeveler; bulunmasa bile
    // harita yeni merkeze gitsin diye hemen oraya uç.
    unawaited(_goToMyLocation());
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

  /// Alt liste için: yüklenen paketleri, haritada görünür (filtrelenmiş)
  /// işletmelerin id'lerine göre süzer — böylece arama/kategori/şimdi-al
  /// çipleri liste için de geçerli olur.
  List<PackageModel> get _visiblePackages {
    final state = context.read<MapBloc>().state;
    if (state is! MapLoaded) return const [];
    final visibleIds = _visibleBusinesses.map((b) => b.id).toSet();
    return state.packages
        .where((p) => visibleIds.contains(p.businessId))
        .toList();
  }

  void _openPackage(PackageModel package) {
    final favBloc = context.read<FavoritesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: favBloc,
          child: PackageDetailPage(package: package),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state is MapLoading) {
            _markersLoaded = false;
            unawaited(_applyMarkers());
          }
          if (state is MapLoaded) {
            if (!_markersLoaded) {
              _loadMarkers();
            } else if (!listEquals(_lastMarkerBusinesses, state.businesses)) {
              unawaited(_applyMarkers());
            }
            _lastMarkerBusinesses = state.businesses;
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
                    center: Point(coordinates: Position(_lng, _lat)),
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
                  onLocationTap: _openLocationPicker,
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
                                latitude: _lat,
                                longitude: _lng,
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
                    Icons.near_me_outlined,
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

              // Yukarı sürüklenince Keşfet tarzı paket listesine açılan,
              // "N Sürpriz Paket" başlıklı alt panel (kart açıkken gizli).
              if (!hasSelection && state is MapLoaded) _buildPackageSheet(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPackageSheet() {
    final state = context.read<MapBloc>().state;
    final packagesLoading = state is MapLoaded && state.packagesLoading;
    final packages = _visiblePackages;
    return Positioned.fill(
      child: MapPackagesSheet(
        packages: packages,
        count: packagesLoading && packages.isEmpty
            ? _totalPackages
            : packages.length,
        isLoading: packagesLoading && packages.isEmpty && _totalPackages > 0,
        onPackageTap: _openPackage,
      ),
    );
  }

  double _getFabBottomOffset(MapState state) {
    if (state is MapLoaded && state.selectedBusiness != null) {
      // Genişletilmiş TGTG kartının üstünde kal.
      return 430 + MediaQuery.of(context).padding.bottom;
    }
    return MapPackagesSheet.headerHeight(context) +
        14 +
        MediaQuery.of(context).padding.bottom;
  }
}
