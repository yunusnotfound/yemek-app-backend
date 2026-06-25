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
  MapboxMap? _mapController;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  final Map<String, BusinessModel> _annotationIdToBusiness = {};
  bool _markersLoaded = false;
  Cancelable? _tapCancelable;
  PolylineAnnotation? _currentPolyline;

  @override
  void dispose() {
    _tapCancelable?.cancel();
    super.dispose();
  }

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

      // Set up tap listener
      _tapCancelable = _pointAnnotationManager!.tapEvents(
        onTap: (PointAnnotation annotation) {
          _onAnnotationTapped(annotation);
        },
      );

      // Add current location marker first
      await _addCurrentLocationMarker();

      // Load markers after annotation manager is ready
      _loadMarkers();
    } catch (e) {
      debugPrint('Error creating annotation manager: $e');
    }
  }

  Future<void> _drawRoutePolyline(List<dynamic> coordinates) async {
    if (_polylineAnnotationManager == null) return;

    // Clear existing polyline
    if (_currentPolyline != null) {
      await _polylineAnnotationManager!.delete(_currentPolyline!);
      _currentPolyline = null;
    }

    // Convert coordinates to Position list
    // Mapbox Directions API returns coordinates as [lng, lat] pairs
    final positions = coordinates.map((coord) {
      final list = coord as List<dynamic>;
      return Position(list[0] as double, list[1] as double);
    }).toList();

    // Create polyline
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

  void _onAnnotationTapped(PointAnnotation annotation) {
    // Find the business based on the annotation's custom data
    final business = _annotationIdToBusiness[annotation.id];
    if (business == null) return;

    context.read<MapBloc>().add(SelectBusiness(business: business));

    // Request directions if we have user location
    context.read<MapBloc>().add(
      RequestDirections(
        originLat: widget.latitude,
        originLng: widget.longitude,
        destLat: business.latitude,
        destLng: business.longitude,
      ),
    );
  }

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

    // Outer pulse ring (semi-transparent blue)
    final pulsePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A90D9).withValues(alpha: 0.25),
          const Color(0xFF4A90D9).withValues(alpha: 0.0),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size / 2));
    canvas.drawCircle(center, size / 2, pulsePaint);

    // White border circle
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, size / 4.5, borderPaint);

    // Inner solid blue circle
    final innerPaint = Paint()..color = const Color(0xFF4A90D9);
    canvas.drawCircle(center, size / 4.5, innerPaint);

    // White center dot
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, size / 14, dotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _loadMarkers() async {
    final state = context.read<MapBloc>().state;
    if (state is! MapLoaded || _markersLoaded) return;

    final businesses = state.businesses;
    if (businesses.isEmpty || _pointAnnotationManager == null) return;

    _markersLoaded = true;
    _annotationIdToBusiness.clear();

    for (final business in businesses) {
      final letter = business.name.isNotEmpty ? business.name[0] : '?';

      try {
        final iconBytes = await _createGlowMarkerIcon(letter);

        final annotation = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(business.longitude, business.latitude),
          ),
          image: iconBytes,
          iconSize: 0.65,
          iconAnchor: IconAnchor.CENTER,
        );

        final createdAnnotation = await _pointAnnotationManager!.create(
          annotation,
        );

        // Store mapping for tap handling
        _annotationIdToBusiness[createdAnnotation.id] = business;
      } catch (e) {
        debugPrint('Error creating marker for ${business.name}: $e');
      }
    }
  }

  Future<Uint8List> _createGlowMarkerIcon(
    String letter, {
    bool isSelected = false,
  }) async {
    const size = 180.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final center = Offset(size / 2, size / 2);

    // Outer glow circle (semi-transparent orange)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: isSelected ? 0.6 : 0.4),
          AppColors.primary.withValues(alpha: 0.0),
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size / 2));
    canvas.drawCircle(center, size / 2, glowPaint);

    // Inner solid circle
    final innerPaint = Paint()
      ..color = isSelected ? AppColors.primaryDark : AppColors.primary;
    canvas.drawCircle(center, size / 3.2, innerPaint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, size / 3.2, borderPaint);

    // Letter text
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
          fontFamily: 'Korolev',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _animateToLocation(
    double lat,
    double lng, {
    double zoom = 15.0,
  }) async {
    if (_mapController == null) return;

    await _mapController!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    await _animateToLocation(widget.latitude, widget.longitude, zoom: 14.0);
  }

  void _onCloseCard() {
    context.read<MapBloc>().add(const ClearSelection());
  }

  void _onNavigate(BusinessModel business) async {
    // Try Google Maps app first, then Apple Maps, then web Google Maps
    final googleMapsUrl =
        'comgooglemaps://?daddr=${business.latitude},${business.longitude}&directionsmode=driving';

    final appleMapsUrl =
        'maps://maps.apple.com/?daddr=${business.latitude},${business.longitude}&dirflg=d';

    final webGoogleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${business.latitude},${business.longitude}&travelmode=driving';

    // Try Google Maps app first
    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl));
    }
    // Then try Apple Maps
    else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(Uri.parse(appleMapsUrl));
    }
    // Fallback to web Google Maps
    else if (await canLaunchUrl(Uri.parse(webGoogleMapsUrl))) {
      await launchUrl(
        Uri.parse(webGoogleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _onViewDetails(BusinessModel business) {
    // No-op for now - detail page doesn't exist yet
    debugPrint('View details tapped for ${business.name}');
  }

  void _onMapTap(MapContentGestureContext context) {
    // Clear selection when tapping on empty map area
    final mapState = this.context.read<MapBloc>().state;
    if (mapState is MapLoaded && mapState.selectedBusiness != null) {
      this.context.read<MapBloc>().add(const ClearSelection());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark background for map
      body: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state is MapLoaded) {
            if (!_markersLoaded) {
              _loadMarkers();
            }

            // Draw or clear route polyline based on directions
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
          return Stack(
            children: [
              // Mapbox Map - Positioned.fill ensures the PlatformView
              // gets explicit tight constraints inside the Stack
              Positioned.fill(
                child: MapWidget(
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(widget.longitude, widget.latitude),
                    ),
                    zoom: 13.0,
                  ),
                  styleUri: MapboxStyles.DARK, // GTA dark theme
                  onMapCreated: _onMapCreated,
                  onTapListener: _onMapTap,
                ),
              ),

              // Loading overlay
              if (state is MapLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),

              // Error overlay
              if (state is MapError)
                Positioned(
                  top: MediaQuery.of(context).padding.top + AppSpacing.md,
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
              if (state is MapLoaded && state.selectedBusiness != null)
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
            ],
          );
        },
      ),
    );
  }

  double _getFabBottomOffset(MapState state) {
    if (state is MapLoaded && state.selectedBusiness != null) {
      // Account for business card height + padding
      return 260;
    }
    return AppSpacing.xl + MediaQuery.of(context).padding.bottom;
  }
}
