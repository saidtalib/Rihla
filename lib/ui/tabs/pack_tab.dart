import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../screens/social_chat_screen.dart';

/// "The Pack" tab: Combined Chat + Member management.
class PackTab extends StatefulWidget {
  const PackTab(
      {super.key, required this.trip, required this.onTripUpdated});
  final Trip trip;
  final ValueChanged<Trip> onTripUpdated;

  @override
  State<PackTab> createState() => _PackTabState();
}

class _PackTabState extends State<PackTab> with AutomaticKeepAliveClientMixin {
  bool _showMembers = false;

  @override
  bool get wantKeepAlive => true;

  String get _myUid => TripService.instance.currentUserId;
  bool get _isAdmin => TripService.instance.currentUserIsAdmin(widget.trip);

  // ── Promote member to admin ─────────────────
  Future<void> _promoteToAdmin(String memberId) async {
    final ar = AppSettings.of(context).isArabic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'ترقية لمشرف؟' : 'Promote to Admin?'),
        content: Text(ar
            ? 'سيتمكن هذا العضو من إدارة الرحلة'
            : 'This member will be able to manage the trip'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'ترقية' : 'Promote')),
        ],
      ),
    );
    if (confirmed != true) return;
    await TripService.instance.promoteToAdmin(widget.trip.id, memberId);
    final updatedMembers = Map<String, String>.from(widget.trip.members);
    updatedMembers[memberId] = 'admin';
    widget.onTripUpdated(widget.trip.copyWith(members: updatedMembers));
  }

  // ── Remove member ───────────────────────────
  Future<void> _removeMember(String memberId) async {
    final ar = AppSettings.of(context).isArabic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'إزالة العضو؟' : 'Remove Member?'),
        content: Text(ar
            ? 'سيتم إزالة هذا العضو من الرحلة'
            : 'This member will be removed from the trip'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'إزالة' : 'Remove',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await TripService.instance.removeMember(widget.trip.id, memberId);
    final updatedMembers = Map<String, String>.from(widget.trip.members)
      ..remove(memberId);
    final updatedPaid = List<String>.from(widget.trip.paidMembers)
      ..remove(memberId);
    widget.onTripUpdated(
        widget.trip.copyWith(members: updatedMembers, paidMembers: updatedPaid));
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

    return Column(
      children: [
        // ── Members toggle bar ────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: dark ? RihlaColors.darkCard : RihlaColors.saharaSand,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.groups_rounded,
                  color: RihlaColors.sunsetOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                ar
                    ? 'العزوة (${widget.trip.paidMembers.length})'
                    : 'The Pack (${widget.trip.paidMembers.length})',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _showMembers = !_showMembers),
                icon: Icon(
                  _showMembers
                      ? Icons.chat_rounded
                      : Icons.manage_accounts_rounded,
                  size: 18,
                ),
                label: Text(
                  _showMembers
                      ? (ar ? 'الدردشة' : 'Chat')
                      : (ar ? 'إدارة المجموعة' : 'Manage Group'),
                  style: TextStyle(fontFamily: fontFamily, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // ── Content area ──────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showMembers
                ? _buildMemberList(ar, dark, fontFamily!, headingColor)
                : SocialChatScreen(
                    key: const ValueKey('social_chat'),
                    trip: widget.trip,
                    onTripUpdated: widget.onTripUpdated,
                  ),
          ),
        ),
      ],
    );
  }

  // ── Member list ───────────────────────────────
  Widget _buildMemberList(
      bool ar, bool dark, String fontFamily, Color headingColor) {
    final members = widget.trip.members;
    final memberIds = members.keys.toList();

    return ListView.builder(
      key: const ValueKey('members'),
      padding: const EdgeInsets.all(12),
      itemCount: memberIds.length,
      itemBuilder: (context, i) {
        final uid = memberIds[i];
        final role = members[uid] ?? 'member';
        final isThisAdmin = role == 'admin' || uid == widget.trip.adminId;
        final isMe = uid == _myUid;
        final isCreator = uid == widget.trip.adminId;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isThisAdmin
                  ? RihlaColors.sunsetOrange.withValues(alpha: 0.15)
                  : RihlaColors.jungleGreen.withValues(alpha: 0.1),
              child: Icon(
                isThisAdmin ? Icons.star_rounded : Icons.person_rounded,
                color: isThisAdmin
                    ? RihlaColors.sunsetOrange
                    : RihlaColors.jungleGreen,
                size: 22,
              ),
            ),
            title: Text(
              isMe
                  ? (ar ? 'أنت' : 'You')
                  : '${ar ? "عضو" : "Member"} ${uid.substring(0, 6)}',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w600,
                color: dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark,
              ),
            ),
            subtitle: Text(
              isCreator
                  ? (ar ? '👑 منشئ الرحلة' : '👑 Trip Creator')
                  : isThisAdmin
                      ? (ar ? '⭐ مشرف' : '⭐ Admin')
                      : (ar ? 'عضو' : 'Member'),
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 12,
                color: headingColor.withValues(alpha: 0.6),
              ),
            ),
            trailing: (_isAdmin && !isMe && !isCreator)
                ? PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'promote') _promoteToAdmin(uid);
                      if (action == 'remove') _removeMember(uid);
                    },
                    itemBuilder: (_) => [
                      if (!isThisAdmin)
                        PopupMenuItem(
                          value: 'promote',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward_rounded,
                                  size: 18, color: RihlaColors.sunsetOrange),
                              const SizedBox(width: 8),
                              Text(ar ? 'ترقية لمشرف' : 'Promote to Admin'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline_rounded,
                                size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(ar ? 'إزالة' : 'Remove',
                                style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
