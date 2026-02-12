import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../ui/theme/app_theme.dart';
import '../screens/social_chat_screen.dart';

/// "The Pack" tab: Combined Chat + Member management.
/// Uses a StreamBuilder on the trip document for real-time member sync.
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

  /// Resolved uid → displayName from Firestore `users` collection.
  Map<String, String> _names = {};
  bool _namesLoaded = false;

  // Cache stream so StreamBuilder doesn't re-subscribe on every build
  late final Stream<Trip?> _tripStream;

  @override
  bool get wantKeepAlive => true;

  String get _myUid => TripService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _tripStream = TripService.instance.tripStream(widget.trip.id);
    _loadNames(widget.trip.members.keys.toList());
  }

  Future<void> _loadNames(List<String> uids) async {
    TripService.instance.clearNameCache();
    final names = await TripService.instance.resolveNames(uids);
    if (mounted) setState(() { _names = names; _namesLoaded = true; });
  }

  String _displayName(String uid) {
    if (uid == _myUid) {
      return AppSettings.of(context).isArabic ? 'أنت' : 'You';
    }
    return _names[uid] ?? TripService.instance.getCachedName(uid);
  }

  // ── Promote member to admin ─────────────────
  Future<void> _promoteToAdmin(String memberId, Trip trip) async {
    final ar = AppSettings.of(context).isArabic;
    final name = _displayName(memberId);
    final confirmed = await _confirmDialog(
      title: ar ? 'ترقية لمشرف؟' : 'Promote to Admin?',
      content: ar
          ? 'هل أنت متأكد من ترقية $name لمشرف؟'
          : 'Are you sure you want to promote $name to Admin?',
      confirmLabel: ar ? 'ترقية' : 'Promote',
      isDestructive: false,
    );
    if (!confirmed) return;
    await TripService.instance.promoteToAdmin(trip.id, memberId);
  }

  // ── Demote admin to member (creator only) ───
  Future<void> _demoteToMember(String memberId, Trip trip) async {
    final ar = AppSettings.of(context).isArabic;
    final name = _displayName(memberId);
    final confirmed = await _confirmDialog(
      title: ar ? 'تخفيض من مشرف؟' : 'Demote Admin?',
      content: ar
          ? 'هل أنت متأكد من تخفيض $name لعضو عادي؟'
          : 'Are you sure you want to demote $name to Member?',
      confirmLabel: ar ? 'تخفيض' : 'Demote',
      isDestructive: true,
    );
    if (!confirmed) return;
    await TripService.instance.demoteToMember(trip.id, memberId);
  }

  // ── Remove member ───────────────────────────
  Future<void> _removeMember(String memberId, Trip trip) async {
    final ar = AppSettings.of(context).isArabic;
    final name = _displayName(memberId);
    final confirmed = await _confirmDialog(
      title: ar ? 'إزالة العضو؟' : 'Remove Member?',
      content: ar
          ? 'هل أنت متأكد من إزالة $name من الرحلة؟'
          : 'Are you sure you want to remove $name from the trip?',
      confirmLabel: ar ? 'إزالة' : 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;
    await TripService.instance.removeMember(trip.id, memberId);
  }

  Future<bool> _confirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required bool isDestructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppSettings.of(context).isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: isDestructive ? R.error : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // ── Toggle bar ──────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              // Use streamed count
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.trip.id)
                    .snapshots(),
                builder: (ctx, snap) {
                  final count = snap.hasData
                      ? (((snap.data!.data() as Map<String, dynamic>?)?['paid_members']
                              as List?) ??
                          []).length
                      : widget.trip.paidMembers.length;
                  return Text(
                    ar ? 'العزوة ($count)' : 'The Pack ($count)',
                    style: tt.titleSmall,
                  );
                },
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
                  style: tt.labelSmall,
                ),
              ),
            ],
          ),
        ),

        // ── Content area ────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showMembers
                ? _buildMemberListStream(ar, cs, tt)
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

  // ═════════════════════════════════════════════
  //  Real-time Member List via StreamBuilder
  // ═════════════════════════════════════════════
  Widget _buildMemberListStream(bool ar, ColorScheme cs, TextTheme tt) {
    return StreamBuilder<Trip?>(
      stream: _tripStream,
      builder: (context, snap) {
        final trip = snap.data ?? widget.trip;

        // Sync to parent so other tabs pick up changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && snap.hasData && snap.data != null) {
            widget.onTripUpdated(trip);
          }
        });

        // Resolve names for any new members
        final memberUids = trip.members.keys.toList();
        final hasNewMembers = memberUids.any((uid) => !_names.containsKey(uid));
        if (hasNewMembers) {
          _loadNames(memberUids);
        }

        return _buildMemberList(trip, ar, cs, tt);
      },
    );
  }

  Widget _buildMemberList(Trip trip, bool ar, ColorScheme cs, TextTheme tt) {
    final memberIds = trip.members.keys.toList();
    final canManage = trip.canManageMembers(_myUid);

    if (!_namesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      key: const ValueKey('members'),
      padding: const EdgeInsets.all(12),
      itemCount: memberIds.length,
      itemBuilder: (context, i) {
        final uid = memberIds[i];
        final isCreator = trip.isCreator(uid);
        final isThisAdmin = trip.isAdmin(uid);
        final isMe = uid == _myUid;

        final showRemove = canManage && trip.canRemove(_myUid, uid);
        final showPromote = canManage && trip.canPromote(_myUid, uid);
        final showDemote = canManage && trip.canDemote(_myUid, uid);
        final hasAnyAction = showRemove || showPromote || showDemote;

        final name = _displayName(uid);

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCreator
                  ? R.warning.withValues(alpha: 0.15)
                  : isThisAdmin
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest,
              child: Icon(
                isCreator
                    ? Icons.shield_rounded
                    : isThisAdmin
                        ? Icons.star_rounded
                        : Icons.person_rounded,
                color: isCreator
                    ? R.warning
                    : isThisAdmin
                        ? cs.primary
                        : cs.onSurfaceVariant,
                size: 22,
              ),
            ),
            title: Text(
              isMe ? '$name (${ar ? 'أنت' : 'You'})' : name,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              isCreator
                  ? (ar ? '👑 منشئ الرحلة' : '👑 Trip Creator')
                  : isThisAdmin
                      ? (ar ? '⭐ مشرف' : '⭐ Admin')
                      : (ar ? 'عضو' : 'Member'),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            trailing: hasAnyAction
                ? PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'promote') _promoteToAdmin(uid, trip);
                      if (action == 'demote') _demoteToMember(uid, trip);
                      if (action == 'remove') _removeMember(uid, trip);
                    },
                    itemBuilder: (_) => [
                      if (showPromote)
                        PopupMenuItem(
                          value: 'promote',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward_rounded,
                                  size: 18, color: cs.primary),
                              const SizedBox(width: 8),
                              Text(ar ? 'ترقية لمشرف' : 'Promote to Admin'),
                            ],
                          ),
                        ),
                      if (showDemote)
                        PopupMenuItem(
                          value: 'demote',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded,
                                  size: 18, color: R.warning),
                              const SizedBox(width: 8),
                              Text(ar ? 'تخفيض لعضو' : 'Demote to Member',
                                  style: TextStyle(color: R.warning)),
                            ],
                          ),
                        ),
                      if (showRemove)
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(Icons.remove_circle_outline_rounded,
                                  size: 18, color: R.error),
                              const SizedBox(width: 8),
                              Text(ar ? 'إزالة من الرحلة' : 'Remove from Trip',
                                  style: const TextStyle(color: R.error)),
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
