import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';

/// Home Tab: "TripIt" chain of cities with admin controls.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.trip, required this.onTripUpdated});
  final Trip trip;
  final ValueChanged<Trip> onTripUpdated;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool get _isAdmin => TripService.instance.currentUserIsAdmin(widget.trip);

  // ── Edit title (admin only) ─────────────────
  Future<void> _editTitle() async {
    final ar = AppSettings.of(context).isArabic;
    final ctrl = TextEditingController(text: widget.trip.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'تعديل عنوان الرحلة' : 'Edit Trip Title'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: ar ? 'عنوان جديد...' : 'New title...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(ar ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == widget.trip.title) {
      return;
    }
    await TripService.instance.updateTitle(widget.trip.id, newTitle);
    widget.onTripUpdated(widget.trip.copyWith(title: newTitle));
  }

  // ── Delete a location (admin only) ──────────
  Future<void> _deleteLocation(int index) async {
    final ar = AppSettings.of(context).isArabic;
    final loc = widget.trip.locations[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'حذف الموقع؟' : 'Remove Stop?'),
        content: Text(
          ar
              ? 'هل تريد حذف "${loc.name}" من المسار؟'
              : 'Remove "${loc.name}" from the route?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'حذف' : 'Remove',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = List<TripLocation>.from(widget.trip.locations)
      ..removeAt(index);
    await TripService.instance.removeLocation(widget.trip.id, updated);
    widget.onTripUpdated(widget.trip.copyWith(locations: updated));
  }

  // ── Pick Safari icon based on index ─────────
  IconData _safariIcon(int index, int total) {
    if (index == 0) return Icons.flight_takeoff_rounded;
    if (index == total - 1) return Icons.flag_rounded;
    // Alternate between jeep and tent for middle stops
    return index.isEven ? Icons.directions_car_rounded : Icons.cabin_rounded;
  }

  Color _safariColor(int index, int total) {
    if (index == 0) return RihlaColors.jungleGreen;
    if (index == total - 1) return RihlaColors.sunsetOrange;
    return RihlaColors.jungleGreenLight;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;
    final headingColor =
        dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen;
    final subColor = headingColor.withValues(alpha: 0.6);

    final trip = widget.trip;
    final locs = trip.locations;

    return CustomScrollView(
      slivers: [
        // ── Header with title ───────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [RihlaColors.jungleGreenDark, RihlaColors.jungleGreen],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: RihlaColors.jungleGreen.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌍', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        trip.title,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            color: Colors.white70, size: 20),
                        tooltip: ar ? 'تعديل' : 'Edit',
                        onPressed: _editTitle,
                      ),
                  ],
                ),
                if (trip.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    trip.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.location_on_rounded,
                      label: '${locs.length} ${ar ? "محطات" : "stops"}',
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.people_rounded,
                      label:
                          '${trip.paidMembers.length} ${ar ? "أعضاء" : "members"}',
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: trip.isPublic
                          ? Icons.public_rounded
                          : Icons.lock_rounded,
                      label: trip.isPublic
                          ? (ar ? 'عامة' : 'Public')
                          : (ar ? 'خاصة' : 'Private'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Transport suggestions ───────────────
        if (trip.transportSuggestions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ar ? '🚗 خيارات النقل' : '🚗 Transport Options',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: headingColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...trip.transportSuggestions.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () {
                            // If it looks like a URL, launch it
                            final urlMatch = RegExp(r'https?://\S+').firstMatch(s);
                            if (urlMatch != null) {
                              launchUrl(Uri.parse(urlMatch.group(0)!),
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: dark
                                  ? RihlaColors.darkCard
                                  : RihlaColors.saharaSand,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 16, color: RihlaColors.sunsetOrange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      fontFamily: fontFamily,
                                      fontSize: 13,
                                      color: dark
                                          ? RihlaColors.darkText
                                          : RihlaColors.jungleGreenDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

        // ── "Chain of Cities" heading ───────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              ar ? '🗺️ مسار الرحلة' : '🗺️ Route Chain',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
          ),
        ),

        // ── Chain of cities ─────────────────────
        if (locs.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  ar ? 'لا توجد محطات بعد' : 'No stops yet',
                  style: TextStyle(
                      fontFamily: fontFamily, fontSize: 16, color: subColor),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final loc = locs[index];
                final isLast = index == locs.length - 1;
                return _CityChainTile(
                  location: loc,
                  index: index,
                  total: locs.length,
                  isLast: isLast,
                  isDark: dark,
                  isArabic: ar,
                  fontFamily: fontFamily!,
                  icon: _safariIcon(index, locs.length),
                  iconColor: _safariColor(index, locs.length),
                  isAdmin: _isAdmin,
                  onDelete: () => _deleteLocation(index),
                );
              },
              childCount: locs.length,
            ),
          ),

        // ── Itinerary section ───────────────────
        if (trip.itinerary.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                ar ? '📅 الجدول اليومي' : '📅 Daily Itinerary',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final day = trip.itinerary[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                RihlaColors.sunsetOrange.withValues(alpha: 0.15),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: RihlaColors.sunsetOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 14,
                                height: 1.5,
                                color: dark
                                    ? RihlaColors.darkText
                                    : RihlaColors.jungleGreenDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: trip.itinerary.length,
            ),
          ),
        ],

        // Bottom padding
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

// ── Info chip for the header ────────────────────
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── City Chain Tile ─────────────────────────────
class _CityChainTile extends StatelessWidget {
  const _CityChainTile({
    required this.location,
    required this.index,
    required this.total,
    required this.isLast,
    required this.isDark,
    required this.isArabic,
    required this.fontFamily,
    required this.icon,
    required this.iconColor,
    required this.isAdmin,
    required this.onDelete,
  });

  final TripLocation location;
  final int index;
  final int total;
  final bool isLast;
  final bool isDark;
  final bool isArabic;
  final String fontFamily;
  final IconData icon;
  final Color iconColor;
  final bool isAdmin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? RihlaColors.darkText : RihlaColors.jungleGreenDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Timeline connector ──────────────
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  // Top connector line
                  if (index > 0)
                    Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  // Circle icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: iconColor.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  // Bottom connector line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              iconColor.withValues(alpha: 0.4),
                              iconColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── City card ───────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? RihlaColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isArabic ? "المحطة" : "Stop"} ${index + 1} ${isArabic ? "من" : "of"} $total',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Admin delete button
                    if (isAdmin)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: Colors.red.shade300, size: 20),
                        tooltip: isArabic ? 'حذف' : 'Remove',
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
