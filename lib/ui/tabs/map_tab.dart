import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/live_location_service.dart';

/// Interactive Google Map with default layers, route polyline & live location.
class MapTab extends StatefulWidget {
  const MapTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;

  // Map type (Default / Satellite / Terrain)
  MapType _mapType = MapType.normal;

  // Share with Pack: when true, we write our position to Firestore (throttled)
  bool _sharingWithPack = false;
  bool _liveLocationOn = false;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<List<LiveLocationEntry>>? _liveLocationsSub;
  List<LiveLocationEntry> _liveEntries = [];

  // Throttle writes: min 15s or ~50m movement
  static const _throttleDuration = Duration(seconds: 15);
  static const _throttleDistanceMeters = 50.0;
  DateTime? _lastLiveWriteAt;
  double? _lastLiveLat;
  double? _lastLiveLng;

  // Selected marker card
  TripLocation? _selectedLocation;
  int? _selectedIndex;

  // Live member avatar icons (uid -> descriptor); fallback to colored pin
  final Map<String, BitmapDescriptor> _avatarIcons = {};
  final Set<String> _loadingAvatars = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _liveLocationsSub = LiveLocationService.instance
        .streamLiveLocations(widget.trip.id)
        .listen((list) {
      if (mounted) {
        setState(() => _liveEntries = list);
        _loadAvatarsForEntries(list);
      }
    });
  }

  /// Load avatar image from [entry.photoUrl], resize, and set _avatarIcons.
  Future<void> _loadAvatarsForEntries(List<LiveLocationEntry> entries) async {
    for (final entry in entries) {
      final url = entry.photoUrl;
      if (url == null || url.isEmpty) continue;
      if (_avatarIcons.containsKey(entry.uid) || _loadingAvatars.contains(entry.uid)) continue;
      _loadingAvatars.add(entry.uid);
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200 || !mounted) continue;
        final decoded = img.decodeImage(response.bodyBytes);
        if (decoded == null || !mounted) continue;
        final resized = img.copyResize(decoded, width: 32, height: 32);
        final circular = img.copyCropCircle(resized, radius: 16);
        final pngBytes = img.encodePng(circular);
        if (pngBytes.isEmpty || !mounted) continue;
        final descriptor = BitmapDescriptor.bytes(pngBytes);
        if (!mounted) continue;
        setState(() {
          _avatarIcons[entry.uid] = descriptor;
        });
      } catch (_) {
        // Keep default pin on failure
      } finally {
        if (mounted) _loadingAvatars.remove(entry.uid);
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _liveLocationsSub?.cancel();
    if (_sharingWithPack) {
      LiveLocationService.instance.clearMyLiveLocation(widget.trip.id);
    }
    super.dispose();
  }

  // ── Markers (trip locations) ────────────────────
  Set<Marker> get _markers {
    final locs = widget.trip.locations;
    final markers = <Marker>{};

    for (int i = 0; i < locs.length; i++) {
      final loc = locs[i];
      markers.add(Marker(
        markerId: MarkerId('loc_$i'),
        position: LatLng(loc.lat, loc.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          i == 0
              ? BitmapDescriptor.hueGreen
              : i == locs.length - 1
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: loc.name,
          snippet: '${_stopLabel(loc)} · ${i + 1}/${locs.length}',
        ),
        onTap: () => _onMarkerTapped(loc, i),
      ));
    }

    return markers;
  }

  /// Hue from uid hash so each Pack member has a distinct marker color.
  static double _hueFromUid(String uid) {
    int h = uid.hashCode.abs();
    const hues = [
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueCyan,
      BitmapDescriptor.hueAzure,
      BitmapDescriptor.hueRose,
      BitmapDescriptor.hueMagenta,
    ];
    return hues[h % hues.length].toDouble();
  }

  // ── Live Pack member markers (user avatar when available, else colored pin) ──
  Set<Marker> get _liveMemberMarkers {
    final set = <Marker>{};
    for (final entry in _liveEntries) {
      final icon = _avatarIcons[entry.uid] ??
          BitmapDescriptor.defaultMarkerWithHue(_hueFromUid(entry.uid));
      set.add(Marker(
        markerId: MarkerId('live_${entry.uid}'),
        position: LatLng(entry.lat, entry.lng),
        icon: icon,
        infoWindow: InfoWindow(
          title: entry.displayName.isNotEmpty ? entry.displayName : 'Pack',
          snippet: 'Live',
        ),
      ));
    }
    return set;
  }

  Set<Marker> get _allMarkers => {..._markers, ..._liveMemberMarkers};

  String _stopLabel(TripLocation loc) {
    if (loc.isOvernight) return 'Overnight';
    switch (loc.transportType) {
      case TransportType.drive:
        return 'Drive';
      case TransportType.flight:
        return 'Flight';
      case TransportType.train:
        return 'Train';
      case TransportType.ferry:
        return 'Ferry';
      case TransportType.unknown:
        return 'Stop';
    }
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
        color: RihlaColors.sunsetOrange,
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

  void _zoomIn() {
    _mapController?.getZoomLevel().then((z) {
      _mapController?.animateCamera(CameraUpdate.zoomTo(z + 1));
    });
  }

  void _zoomOut() {
    _mapController?.getZoomLevel().then((z) {
      _mapController?.animateCamera(CameraUpdate.zoomTo((z - 1).clamp(2.0, 21.0)));
    });
  }

  // ── Navigate to Google Maps ─────────────────────
  Future<void> _openExternalMaps(TripLocation loc) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${loc.lat},${loc.lng}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ── Share with Pack (crosshair): confirm dialog, toggle on/off ──
  Future<void> _toggleShareWithPack() async {
    final ar = AppSettings.of(context).isArabic;

    if (_sharingWithPack) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ar ? 'إيقاف المشاركة' : 'Stop sharing?'),
          content: Text(
            ar
                ? 'لن يتمكن العزوة من رؤية موقعك على الخريطة.'
                : 'The Pack will no longer see your location on the map.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'إيقاف' : 'Stop'),
            ),
          ],
        ),
      );
      if (stop != true || !mounted) return;
      await _positionStream?.cancel();
      _positionStream = null;
      await LiveLocationService.instance.clearMyLiveLocation(widget.trip.id);
      setState(() {
        _sharingWithPack = false;
        _liveLocationOn = false;
      });
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_rounded, color: RihlaColors.jungleGreen, size: 40),
        title: Text(ar ? 'مشاركة موقعك' : 'Share your location?'),
        content: Text(
          ar
              ? 'سيتمكن العزوة من رؤية موقعك على الخريطة. يمكنك إيقاف المشاركة في أي وقت.'
              : 'The Pack will see your location on the map. You can stop sharing anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ar ? 'لاحقاً' : 'Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'مشاركة' : 'Share'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تفعيل خدمة الموقع' : 'Please enable location services'),
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
          content: Text(ar ? 'تم رفض إذن الموقع' : 'Location permission denied'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم رفض إذن الموقع نهائياً' : 'Location permission permanently denied'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _sharingWithPack = true;
      _liveLocationOn = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'Pack';
    final photoUrl = user?.photoURL;

    void writeIfThrottleOk(double lat, double lng) {
      final now = DateTime.now();
      final okTime = _lastLiveWriteAt == null ||
          now.difference(_lastLiveWriteAt!).inSeconds >= _throttleDuration.inSeconds;
      final okDist = _lastLiveLat == null ||
          Geolocator.distanceBetween(_lastLiveLat!, _lastLiveLng!, lat, lng) >= _throttleDistanceMeters;
      if (okTime || okDist) {
        _lastLiveWriteAt = now;
        _lastLiveLat = lat;
        _lastLiveLng = lng;
        LiveLocationService.instance.setMyLiveLocation(
          widget.trip.id,
          lat: lat,
          lng: lng,
          displayName: displayName,
          photoUrl: photoUrl,
        );
      }
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      writeIfThrottleOk(pos.latitude, pos.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
    } catch (e) {
      debugPrint('[MapTab] Error getting position: $e');
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!_sharingWithPack) return;
      writeIfThrottleOk(pos.latitude, pos.longitude);
      if (_liveLocationOn && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
      }
    });
  }

  // ── Map type toggle ─────────────────────────────
  void _cycleMapType() {
    setState(() {
      switch (_mapType) {
        case MapType.normal:
          _mapType = MapType.satellite;
          break;
        case MapType.satellite:
          _mapType = MapType.terrain;
          break;
        default:
          _mapType = MapType.normal;
      }
    });
  }

  String _mapTypeLabel(bool ar) {
    switch (_mapType) {
      case MapType.normal:
        return ar ? 'عادي' : 'Default';
      case MapType.satellite:
        return ar ? 'قمر صناعي' : 'Satellite';
      case MapType.terrain:
        return ar ? 'تضاريس' : 'Terrain';
      default:
        return '';
    }
  }

  IconData get _mapTypeIcon {
    switch (_mapType) {
      case MapType.normal:
        return Icons.map_outlined;
      case MapType.satellite:
        return Icons.satellite_alt_rounded;
      case MapType.terrain:
        return Icons.terrain_rounded;
      default:
        return Icons.map_outlined;
    }
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
        // ── Google Map (default style, full gestures) ──
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _initialCenter, zoom: 5),
          mapType: _mapType,
          markers: _allMarkers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          // Full default navigation gestures
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: true,
          compassEnabled: true,
          onMapCreated: (ctrl) {
            _mapController = ctrl;
            Future.delayed(const Duration(milliseconds: 500), _fitBounds);
          },
          onTap: (_) => _dismissCard(),
        ),

        // ── Control buttons (top-right) ───────────────
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              // Map type toggle
              _MapFab(
                icon: _mapTypeIcon,
                label: _mapTypeLabel(ar),
                tooltip: ar ? 'نوع الخريطة' : 'Map Type',
                onTap: _cycleMapType,
              ),
              const SizedBox(height: 8),
              // Live location (hidden on web — browser handles geolocation)
              if (!kIsWeb)
                _MapFab(
                  icon: _sharingWithPack
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  tooltip: _sharingWithPack
                      ? (ar ? 'إيقاف المشاركة' : 'Stop sharing')
                      : (ar ? 'مشاركة موقعي مع العزوة' : 'Share with Pack'),
                  isActive: _sharingWithPack,
                  onTap: _toggleShareWithPack,
                ),
              if (!kIsWeb) const SizedBox(height: 8),
              // Fit all markers
              _MapFab(
                icon: Icons.zoom_out_map_rounded,
                tooltip: ar ? 'عرض الكل' : 'Fit All',
                onTap: _fitBounds,
              ),
            ],
          ),
        ),

        // ── Zoom +/- buttons (above chips so they are visible) ──
        Positioned(
          bottom: _selectedLocation != null ? 130 + 80 : 80,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapFab(
                icon: Icons.add_rounded,
                tooltip: ar ? 'تكبير' : 'Zoom in',
                onTap: _zoomIn,
              ),
              const SizedBox(height: 6),
              _MapFab(
                icon: Icons.remove_rounded,
                tooltip: ar ? 'تصغير' : 'Zoom out',
                onTap: _zoomOut,
              ),
            ],
          ),
        ),

        // ── Location chips at bottom ──────────────────
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

        // ── Selected location card ────────────────────
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
    this.label,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;
  final String? label;

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
          child: Padding(
            padding: label != null
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                : EdgeInsets.zero,
            child: label != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 20,
                          color: isActive
                              ? Colors.white
                              : RihlaColors.jungleGreen),
                      const SizedBox(width: 6),
                      Text(
                        label!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : RihlaColors.jungleGreen,
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(icon,
                        size: 22,
                        color: isActive
                            ? Colors.white
                            : RihlaColors.jungleGreen),
                  ),
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
