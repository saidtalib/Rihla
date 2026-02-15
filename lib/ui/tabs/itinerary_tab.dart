import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../theme/app_theme.dart';

/// Itinerary tab: calendar (or day list) → day bubble → POI pop with "Open photos" link.
class ItineraryTab extends StatefulWidget {
  const ItineraryTab({super.key, required this.trip});

  final Trip trip;

  @override
  State<ItineraryTab> createState() => _ItineraryTabState();
}

class _ItineraryTabState extends State<ItineraryTab> {
  DateTime? _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final start = widget.trip.startDate;
    _focusedDay = start ?? DateTime.now();
    _selectedDay = start;
  }

  @override
  void didUpdateWidget(ItineraryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip.startDate != oldWidget.trip.startDate && _focusedDay == null) {
      _focusedDay = widget.trip.startDate ?? DateTime.now();
      _selectedDay = widget.trip.startDate;
    }
  }

  bool get _hasDates =>
      widget.trip.startDate != null && widget.trip.dailyAgenda.isNotEmpty;

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DayAgenda? _agendaForDay(DateTime day) {
    final key = _dayKey(day);
    for (final a in widget.trip.dailyAgenda) {
      if (a.date == key) return a;
    }
    final start = widget.trip.startDate;
    if (start == null) return null;
    final index = day.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    if (index < 1) return null;
    for (final a in widget.trip.dailyAgenda) {
      if (a.dayIndex == index) return a;
    }
    return null;
  }

  bool _isInRange(DateTime day) {
    final start = widget.trip.startDate;
    final end = widget.trip.endDate;
    if (start == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    if (d.isBefore(s)) return false;
    if (end != null) {
      final e = DateTime(end.year, end.month, end.day);
      if (d.isAfter(e)) return false;
    }
    return true;
  }

  void _onDaySelected(DateTime day, DateTime focusedDay) {
    if (!_isInRange(day)) return;
    setState(() {
      _selectedDay = day;
      _focusedDay = focusedDay;
    });
    final agenda = _agendaForDay(day);
    if (agenda != null) _showDayBubble(agenda, day);
  }

  void _showDayBubble(DayAgenda agenda, DateTime day) {
    final ar = AppSettings.of(context).isArabic;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.radiusXl)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: R.indigo, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ar
                          ? 'اليوم ${agenda.dayIndex}${agenda.city != null ? ' – ${agenda.city}' : ''}'
                          : 'Day ${agenda.dayIndex}${agenda.city != null ? ' – ${agenda.city}' : ''}',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: R.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                shrinkWrap: true,
                itemCount: agenda.pois.length,
                itemBuilder: (context, i) {
                  final poi = agenda.pois[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(R.radiusLg),
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: R.indigo.withValues(alpha: 0.12),
                        child: Icon(Icons.place_rounded, color: R.indigo, size: 22),
                      ),
                      title: Text(
                        poi.name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: R.textPrimary,
                        ),
                      ),
                      subtitle: poi.description != null
                          ? Text(
                              poi.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(color: R.textSecondary),
                            )
                          : null,
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showPoiPop(poi);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPoiPop(PoiItem poi) {
    final ar = AppSettings.of(context).isArabic;
    final tt = Theme.of(context).textTheme;
    final query = Uri.encodeComponent(poi.searchQuery ?? poi.name);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.radiusXl)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.place_rounded, color: R.indigo, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    poi.name,
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: R.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (poi.description != null && poi.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                poi.description!,
                style: tt.bodyMedium?.copyWith(color: R.textSecondary),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final url = 'https://www.google.com/search?q=$query+photos';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.photo_library_rounded, size: 20),
              label: Text(ar ? 'فتح صور على الويب' : 'Open photos online'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(R.radiusXl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ar ? 'إغلاق' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppSettings.of(context).isArabic;
    final tt = Theme.of(context).textTheme;

    if (widget.trip.dailyAgenda.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 64,
                color: R.indigo.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                ar ? 'لا يوجد جدول يومي بعد' : 'No daily itinerary yet',
                style: tt.titleMedium?.copyWith(
                  color: R.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                ar
                    ? 'أنشئ رحلة بالذكاء الاصطناعي واذكر التواريخ والأماكن لرؤية الجدول هنا.'
                    : 'Create a trip with AI and include dates and places to see your itinerary here.',
                style: tt.bodyMedium?.copyWith(color: R.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasDates) {
      // Relative mode: list days by index
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            ar ? 'جدول الرحلة' : 'Trip itinerary',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: R.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.trip.dailyAgenda.map((agenda) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(R.radiusXl),
              ),
              elevation: 2,
              child: InkWell(
                onTap: () => _showDayBubble(agenda, DateTime.now()),
                borderRadius: BorderRadius.circular(R.radiusXl),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: R.indigo, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            ar ? 'اليوم ${agenda.dayIndex}' : 'Day ${agenda.dayIndex}',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: R.textPrimary,
                            ),
                          ),
                          if (agenda.city != null) ...[
                            Text(
                              ' · ${agenda.city}',
                              style: tt.titleMedium?.copyWith(color: R.textSecondary),
                            ),
                          ],
                        ],
                      ),
                      if (agenda.pois.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${agenda.pois.length} ${ar ? 'أماكن' : 'places'}',
                          style: tt.bodySmall?.copyWith(color: R.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    final start = widget.trip.startDate!;
    final end = widget.trip.endDate ?? start.add(Duration(days: widget.trip.dailyAgenda.length));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ar ? 'التقويم' : 'Calendar',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: R.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.radiusXl),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TableCalendar<DayAgenda>(
                firstDay: DateTime(start.year, start.month, 1),
                lastDay: end.add(const Duration(days: 31)),
                focusedDay: _focusedDay ?? start,
                eventLoader: (day) {
                  final a = _agendaForDay(day);
                  return a != null ? [a] : [];
                },
                selectedDayPredicate: (day) {
                  if (_selectedDay == null) return false;
                  return _selectedDay!.year == day.year &&
                      _selectedDay!.month == day.month &&
                      _selectedDay!.day == day.day;
                },
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: ar ? StartingDayOfWeek.saturday : StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  defaultTextStyle: tt.bodyMedium!.copyWith(color: R.textPrimary),
                  weekendTextStyle: tt.bodyMedium!.copyWith(color: R.textSecondary),
                  selectedDecoration: BoxDecoration(
                    color: R.indigo,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: R.indigo.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: R.indigo.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  outsideTextStyle: tt.bodySmall!.copyWith(color: R.textSecondary.withValues(alpha: 0.5)),
                ),
                headerStyle: HeaderStyle(
                  titleTextStyle: tt.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: R.textPrimary,
                  ),
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(Icons.chevron_left_rounded, color: R.indigo),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded, color: R.indigo),
                ),
                enabledDayPredicate: (day) => _isInRange(day),
                onDaySelected: _onDaySelected,
                calendarBuilders: CalendarBuilders<DayAgenda>(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: R.indigo,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ar ? 'انقر على يوم لعرض الأماكن' : 'Tap a day to see places',
            style: tt.bodySmall?.copyWith(color: R.textSecondary),
          ),
        ],
      ),
    );
  }
}
