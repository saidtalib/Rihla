import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../ui/theme/app_theme.dart';
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
  Trip get _trip => widget.trip;

  // ── Promote member to admin ─────────────────
  Future<void> _promoteToAdmin(String memberId) async {
    final ar = AppSettings.of(context).isArabic;
    final confirmed = await _confirmDialog(
      title: ar ? 'ترقية لمشرف؟' : 'Promote to Admin?',
      content: ar
          ? 'سيتمكن هذا العضو من إدارة الرحلة'
          : 'This member will be able to manage the trip',
      confirmLabel: ar ? 'ترقية' : 'Promote',
      isDestructive: false,
    );
    if (!confirmed) return;
    await TripService.instance.promoteToAdmin(_trip.id, memberId);
    final m = Map<String, String>.from(_trip.members);
    m[memberId] = 'admin';
    widget.onTripUpdated(_trip.copyWith(members: m));
  }

  // ── Demote admin to member (creator only) ───
  Future<void> _demoteToMember(String memberId) async {
    final ar = AppSettings.of(context).isArabic;
    final confirmed = await _confirmDialog(
      title: ar ? 'تخفيض من مشرف؟' : 'Demote Admin?',
      content: ar
          ? 'سيصبح هذا المشرف عضوًا عاديًا'
          : 'This admin will become a regular member',
      confirmLabel: ar ? 'تخفيض' : 'Demote',
      isDestructive: true,
    );
    if (!confirmed) return;
    await TripService.instance.demoteToMember(_trip.id, memberId);
    final m = Map<String, String>.from(_trip.members);
    m[memberId] = 'member';
    widget.onTripUpdated(_trip.copyWith(members: m));
  }

  // ── Remove member ───────────────────────────
  Future<void> _removeMember(String memberId) async {
    final ar = AppSettings.of(context).isArabic;
    final role = _trip.isAdmin(memberId)
        ? (ar ? 'المشرف' : 'Admin')
        : (ar ? 'العضو' : 'Member');
    final name = memberId.length >= 6 ? memberId.substring(0, 6) : memberId;

    final confirmed = await _confirmDialog(
      title: ar ? 'إزالة $role؟' : 'Remove $role?',
      content: ar
          ? 'هل أنت متأكد من إزالة $role $name من الرحلة؟'
          : 'Are you sure you want to remove $role $name from the trip?',
      confirmLabel: ar ? 'إزالة' : 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;
    await TripService.instance.removeMember(_trip.id, memberId);
    final m = Map<String, String>.from(_trip.members)..remove(memberId);
    final p = List<String>.from(_trip.paidMembers)..remove(memberId);
    widget.onTripUpdated(_trip.copyWith(members: m, paidMembers: p));
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
              Text(
                ar
                    ? 'العزوة (${_trip.paidMembers.length})'
                    : 'The Pack (${_trip.paidMembers.length})',
                style: tt.titleSmall,
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
                ? _buildMemberList(ar, cs, tt)
                : SocialChatScreen(
                    key: const ValueKey('social_chat'),
                    trip: _trip,
                    onTripUpdated: widget.onTripUpdated,
                  ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  //  Member List with Role-Based Actions
  // ═════════════════════════════════════════════
  Widget _buildMemberList(bool ar, ColorScheme cs, TextTheme tt) {
    final memberIds = _trip.members.keys.toList();
    final canManage = _trip.canManageMembers(_myUid);

    return ListView.builder(
      key: const ValueKey('members'),
      padding: const EdgeInsets.all(12),
      itemCount: memberIds.length,
      itemBuilder: (context, i) {
        final uid = memberIds[i];
        final isCreator = _trip.isCreator(uid);
        final isThisAdmin = _trip.isAdmin(uid);
        final isMe = uid == _myUid;

        // Determine which actions the current user can perform on this member
        final showRemove = canManage && _trip.canRemove(_myUid, uid);
        final showPromote = canManage && _trip.canPromote(_myUid, uid);
        final showDemote = canManage && _trip.canDemote(_myUid, uid);
        final hasAnyAction = showRemove || showPromote || showDemote;

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
              isMe ? (ar ? 'أنت' : 'You') : uid.substring(0, 6),
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
                      if (action == 'promote') _promoteToAdmin(uid);
                      if (action == 'demote') _demoteToMember(uid);
                      if (action == 'remove') _removeMember(uid);
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
