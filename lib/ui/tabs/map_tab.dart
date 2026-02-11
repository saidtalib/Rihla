import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';

/// Tab 1: Interactive Google Map with markers + route polylines.
class MapTab extends StatefulWidget {
  const MapTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;

  @override
  bool get wantKeepAlive => true;

  Set<Marker> get _markers {
    return widget.trip.locations.asMap().entries.map((e) {
      final i = e.key;
      final loc = e.value;
      return Marker(
        markerId: MarkerId('loc_$i'),
        position: LatLng(loc.lat, loc.lng),
        infoWindow: InfoWindow(title: loc.name, snippet: '${i + 1}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          i == 0
              ? BitmapDescriptor.hueGreen
              : i == widget.trip.locations.length - 1
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueRed,
        ),
      );
    }).toSet();
  }

  Set<Polyline> get _polylines {
    if (widget.trip.locations.length < 2) return {};
    final points = widget.trip.locations
        .map((l) => LatLng(l.lat, l.lng))
        .toList();
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: RihlaColors.sunsetOrange,
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  LatLng get _initialCenter {
    if (widget.trip.locations.isEmpty) {
      return const LatLng(23.5880, 58.3829); // Default: Muscat
    }
    final first = widget.trip.locations.first;
    return LatLng(first.lat, first.lng);
  }

  void _fitBounds() {
    if (_mapController == null || widget.trip.locations.length < 2) return;
    final bounds = _calculateBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
  }

  LatLngBounds _calculateBounds() {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final loc in widget.trip.locations) {
      if (loc.lat < minLat) minLat = loc.lat;
      if (loc.lat > maxLat) maxLat = loc.lat;
      if (loc.lng < minLng) minLng = loc.lng;
      if (loc.lng > maxLng) maxLng = loc.lng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

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
            Icon(Icons.map_rounded, size: 64, color: RihlaColors.jungleGreen.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(ar ? 'لا توجد مواقع بعد' : 'No locations yet',
                style: TextStyle(fontFamily: fontFamily, fontSize: 18, color: dark ? RihlaColors.darkText : RihlaColors.jungleGreen)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _initialCenter, zoom: 5),
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (ctrl) {
            _mapController = ctrl;
            Future.delayed(const Duration(milliseconds: 500), _fitBounds);
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),

        // ── Location list overlay ────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (dark ? RihlaColors.darkSurface : RihlaColors.saharaSand).withValues(alpha: 0.95),
                ],
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.trip.locations.length,
              itemBuilder: (context, i) {
                final loc = widget.trip.locations[i];
                return GestureDetector(
                  onTap: () => _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 12),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: dark ? RihlaColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: i == 0
                              ? RihlaColors.jungleGreen
                              : RihlaColors.sunsetOrange,
                          child: Text('${i + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Text(loc.name,
                            style: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
