import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';

// ─────────────────────────────────────────────────
//  Safari-themed Google Map JSON Style
//  Land → Sahara Sand, Nature → Jungle Green, hide POIs
// ─────────────────────────────────────────────────
const _safariMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f4ebd0"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#2D5A27"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f4ebd0"},{"weight":2}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#a8d5e2"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4a7a42"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#e8ddb8"}]},
  {"featureType":"landscape.natural.terrain","elementType":"geometry","stylers":[{"color":"#d4c99a"}]},
  {"featureType":"landscape.natural.landcover","elementType":"geometry","stylers":[{"color":"#2D5A27"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#4A7A42"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#1B3A18"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#FF8C00"},{"weight":1.5}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#cc7000"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#e0d5b0"}]},
  {"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#ede3c4"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.government","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.medical","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.school","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.sports_complex","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.attraction","elementType":"geometry","stylers":[{"color":"#c9b87c"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#2D5A27"},{"weight":1.5}]},
  {"featureType":"administrative.province","elementType":"geometry.stroke","stylers":[{"color":"#4A7A42"},{"weight":0.8}]}
]
''';

/// Interactive Google Map with safari markers, route polyline & live location.
class MapTab extends StatefulWidget {
  const MapTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _iconCache = {};
  Set<Marker> _markers = {};
  bool _iconsReady = false;

  // Live location state
  bool _liveLocationOn = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  // Selected marker card
  TripLocation? _selectedLocation;
  int? _selectedIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // ── Load custom marker icons ────────────────────
  Future<void> _loadIcons() async {
    const iconMap = {
      'drive': 'assets/icons/jeep.png',
      'flight': 'assets/icons/plane.png',
      'train': 'assets/icons/train.png',
      'ferry': 'assets/icons/ferry.png',
      'tent': 'assets/icons/tent.png',
    };

    for (final entry in iconMap.entries) {
      try {
        final descriptor = await _loadScaledIcon(entry.value, 96);
        _iconCache[entry.key] = descriptor;
      } catch (e) {
        debugPrint('[MapTab] Failed to load icon ${entry.key}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _iconsReady = true;
        _buildMarkers();
      });
    }
  }

  /// Load an asset image and scale it to [size] pixels.
  Future<BitmapDescriptor> _loadScaledIcon(String assetPath, int size) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  // ── Build markers from locations ────────────────
  void _buildMarkers() {
    final locs = widget.trip.locations;
    final markers = <Marker>{};

    for (int i = 0; i < locs.length; i++) {
      final loc = locs[i];
      final icon = _getMarkerIcon(loc, i);

      markers.add(Marker(
        markerId: MarkerId('loc_$i'),
        position: LatLng(loc.lat, loc.lng),
        icon: icon,
        onTap: () => _onMarkerTapped(loc, i),
      ));
    }

    // Live location marker
    if (_liveLocationOn && _currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('user_live'),
        position: LatLng(
            _currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    setState(() => _markers = markers);
  }

  BitmapDescriptor _getMarkerIcon(TripLocation loc, int index) {
    if (!_iconsReady) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }

    // Overnight / hotel → tent
    if (loc.isOvernight && _iconCache.containsKey('tent')) {
      return _iconCache['tent']!;
    }

    // Transport-based icon
    switch (loc.transportType) {
      case TransportType.drive:
        return _iconCache['drive'] ?? _fallbackIcon(index);
      case TransportType.flight:
        return _iconCache['flight'] ?? _fallbackIcon(index);
      case TransportType.train:
        return _iconCache['train'] ?? _fallbackIcon(index);
      case TransportType.ferry:
        return _iconCache['ferry'] ?? _fallbackIcon(index);
      case TransportType.unknown:
        return _fallbackIcon(index);
    }
  }

  BitmapDescriptor _fallbackIcon(int index) {
    final total = widget.trip.locations.length;
    if (index == 0) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (index == total - 1) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  // ── Polyline ────────────────────────────────────
  Set<Polyline> get _polylines {
    if (widget.trip.locations.length < 2) return {};
    final points =
        widget.trip.locations.map((l) => LatLng(l.lat, l.lng)).toList();
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: RihlaColors.jungleGreen,
        width: 4,
        patterns: [PatternItem.dash(18), PatternItem.gap(12)],
      ),
    };
  }

  // ── Camera helpers ──────────────────────────────
  LatLng get _initialCenter {
    if (widget.trip.locations.isEmpty) {
      return const LatLng(23.5880, 58.3829); // Muscat
    }
    return LatLng(
        widget.trip.locations.first.lat, widget.trip.locations.first.lng);
  }

  void _fitBounds() {
    if (_mapController == null || widget.trip.locations.length < 2) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final loc in widget.trip.locations) {
      if (loc.lat < minLat) minLat = loc.lat;
      if (loc.lat > maxLat) maxLat = loc.lat;
      if (loc.lng < minLng) minLng = loc.lng;
      if (loc.lng > maxLng) maxLng = loc.lng;
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng)),
      60,
    ));
  }

  // ── Marker tap handler ──────────────────────────
  void _onMarkerTapped(TripLocation loc, int index) {
    setState(() {
      _selectedLocation = loc;
      _selectedIndex = index;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 12),
    );
  }

  void _dismissCard() => setState(() {
        _selectedLocation = null;
        _selectedIndex = null;
      });

  // ── Navigate to Google Maps ─────────────────────
  Future<void> _openExternalMaps(TripLocation loc) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${loc.lat},${loc.lng}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ── Live location toggle ────────────────────────
  Future<void> _toggleLiveLocation() async {
    if (_liveLocationOn) {
      await _positionStream?.cancel();
      _positionStream = null;
      setState(() {
        _liveLocationOn = false;
        _currentPosition = null;
      });
      _buildMarkers();
      return;
    }

    // Check permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please enable location services'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Location permission denied'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Location permission permanently denied'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _liveLocationOn = true);

    // Get initial position
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = pos);
        _buildMarkers();
      }
    } catch (e) {
      debugPrint('[MapTab] Error getting position: $e');
    }

    // Stream updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);
        _buildMarkers();
      }
    });
  }

  // ── Transport icon for the bottom card ──────────
  IconData _transportIconData(TripLocation loc) {
    if (loc.isOvernight) return Icons.cabin_rounded;
    switch (loc.transportType) {
      case TransportType.drive:
        return Icons.directions_car_rounded;
      case TransportType.flight:
        return Icons.flight_rounded;
      case TransportType.train:
        return Icons.train_rounded;
      case TransportType.ferry:
        return Icons.directions_boat_rounded;
      case TransportType.unknown:
        return Icons.location_on_rounded;
    }
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    if (widget.trip.locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_rounded,
                size: 64,
                color: RihlaColors.jungleGreen.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(ar ? 'لا توجد مواقع بعد' : 'No locations yet',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 18,
                    color: dark
                        ? RihlaColors.darkText
                        : RihlaColors.jungleGreen)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // ── Google Map ────────────────────────────
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _initialCenter, zoom: 5),
          markers: _markers,
          polylines: _polylines,
          style: _safariMapStyle,
          myLocationEnabled: _liveLocationOn,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (ctrl) {
            _mapController = ctrl;
            Future.delayed(const Duration(milliseconds: 500), _fitBounds);
            if (_iconsReady) _buildMarkers();
          },
          onTap: (_) => _dismissCard(),
        ),

        // ── Live location toggle FAB ──────────────
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _MapFab(
                icon: _liveLocationOn
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                tooltip: ar ? 'موقعي' : 'My Location',
                isActive: _liveLocationOn,
                onTap: _toggleLiveLocation,
              ),
              const SizedBox(height: 8),
              _MapFab(
                icon: Icons.zoom_out_map_rounded,
                tooltip: ar ? 'عرض الكل' : 'Fit All',
                onTap: _fitBounds,
              ),
            ],
          ),
        ),

        // ── Location chips at bottom ──────────────
        Positioned(
          bottom: _selectedLocation != null ? 130 : 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (dark ? RihlaColors.darkSurface : Colors.white)
                      .withValues(alpha: 0.9),
                ],
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.trip.locations.length,
              itemBuilder: (context, i) {
                final loc = widget.trip.locations[i];
                final isSelected = _selectedIndex == i;
                return GestureDetector(
                  onTap: () => _onMarkerTapped(loc, i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? RihlaColors.jungleGreen
                          : (dark ? RihlaColors.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                            color: isSelected
                                ? RihlaColors.jungleGreen
                                    .withValues(alpha: 0.3)
                                : Colors.black12,
                            blurRadius: isSelected ? 8 : 4)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _transportIconData(loc),
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : RihlaColors.sunsetOrange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.name,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (dark
                                    ? RihlaColors.darkText
                                    : RihlaColors.jungleGreenDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // ── Selected location card ────────────────
        if (_selectedLocation != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _LocationCard(
              location: _selectedLocation!,
              index: _selectedIndex!,
              total: widget.trip.locations.length,
              isDark: dark,
              isArabic: ar,
              fontFamily: fontFamily!,
              transportIcon: _transportIconData(_selectedLocation!),
              onNavigate: () => _openExternalMaps(_selectedLocation!),
              onDismiss: _dismissCard,
            ),
          ),
      ],
    );
  }
}

// ── Floating Action Button for the map ──────────
class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: isActive ? RihlaColors.sunsetOrange : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon,
                size: 22,
                color: isActive ? Colors.white : RihlaColors.jungleGreen),
          ),
        ),
      ),
    );
  }
}

// ── Location detail card ────────────────────────
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.index,
    required this.total,
    required this.isDark,
    required this.isArabic,
    required this.fontFamily,
    required this.transportIcon,
    required this.onNavigate,
    required this.onDismiss,
  });

  final TripLocation location;
  final int index;
  final int total;
  final bool isDark;
  final bool isArabic;
  final String fontFamily;
  final IconData transportIcon;
  final VoidCallback onNavigate;
  final VoidCallback onDismiss;

  String get _transportLabel {
    if (location.isOvernight) return isArabic ? 'مبيت' : 'Overnight';
    switch (location.transportType) {
      case TransportType.drive:
        return isArabic ? 'بالسيارة' : 'Drive';
      case TransportType.flight:
        return isArabic ? 'طيران' : 'Flight';
      case TransportType.train:
        return isArabic ? 'قطار' : 'Train';
      case TransportType.ferry:
        return isArabic ? 'عبّارة' : 'Ferry';
      case TransportType.unknown:
        return isArabic ? 'موقع' : 'Stop';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? RihlaColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: RihlaColors.jungleGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(transportIcon,
                color: RihlaColors.sunsetOrange, size: 26),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  location.name,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? RihlaColors.darkText
                        : RihlaColors.jungleGreenDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            RihlaColors.sunsetOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _transportLabel,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: RihlaColors.sunsetOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isArabic ? "محطة" : "Stop"} ${index + 1}/$total',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 12,
                        color: (isDark
                                ? RihlaColors.darkText
                                : RihlaColors.jungleGreenDark)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Navigate button
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                color: RihlaColors.jungleGreen,
                child: InkWell(
                  onTap: onNavigate,
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.navigation_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isArabic ? 'اذهب' : 'Go',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: RihlaColors.jungleGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
