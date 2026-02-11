import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/chat_service.dart';
import '../../services/trip_service.dart';

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
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  bool _sending = false;
  bool _showMembers = false;

  @override
  bool get wantKeepAlive => true;

  String get _myUid => TripService.instance.currentUserId;
  bool get _isAdmin => TripService.instance.currentUserIsAdmin(widget.trip);

  // ── Scroll to bottom ────────────────────────
  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // ── Send text ───────────────────────────────
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await ChatService.instance.sendText(widget.trip.id, text);
    _scrollToBottom();
  }

  // ── Send photo ──────────────────────────────
  Future<void> _pickAndSendPhoto() async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    setState(() => _sending = true);
    try {
      await ChatService.instance.sendPhoto(widget.trip.id, File(file.path));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Delete message ──────────────────────────
  Future<void> _deleteMessage(ChatMessage msg) async {
    final deleted = await ChatService.instance.deleteMessage(
      widget.trip.id,
      msg,
      isAdminUser: _isAdmin,
    );
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Cannot delete this message'),
            backgroundColor: Colors.red),
      );
    }
  }

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
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
                : _buildChat(ar, dark, fontFamily!),
          ),
        ),

        // ── Input bar (only for chat mode) ────
        if (!_showMembers) _buildInputBar(ar, dark),
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

  // ── Chat messages ─────────────────────────────
  Widget _buildChat(bool ar, bool dark, String fontFamily) {
    return StreamBuilder<List<ChatMessage>>(
      key: const ValueKey('chat'),
      stream: ChatService.instance.messagesStream(widget.trip.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: RihlaColors.jungleGreen));
        }
        final messages = snap.data ?? [];
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 56,
                    color: RihlaColors.jungleGreen.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(
                  ar
                      ? 'لا توجد رسائل بعد. ابدأ المحادثة!'
                      : 'No messages yet. Start chatting!',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: (dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark)
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i];
            final isMe = msg.senderId == _myUid;
            return _ChatBubble(
              message: msg,
              isMe: isMe,
              isDark: dark,
              fontFamily: fontFamily,
              onDelete: () => _deleteMessage(msg),
            );
          },
        );
      },
    );
  }

  // ── Input bar ─────────────────────────────────
  Widget _buildInputBar(bool ar, bool dark) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: dark ? RihlaColors.darkCard : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.photo_camera_rounded,
                    color: RihlaColors.sunsetOrange),
            onPressed: _sending ? null : _pickAndSendPhoto,
          ),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(
                  fontSize: 15,
                  color: dark
                      ? RihlaColors.darkText
                      : RihlaColors.jungleGreenDark),
              decoration: InputDecoration(
                hintText: ar ? 'اكتب رسالة...' : 'Type a message...',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor:
                    dark ? RihlaColors.darkSurface : RihlaColors.saharaSand,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            backgroundColor: RihlaColors.jungleGreen,
            radius: 22,
            child: IconButton(
              icon:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _send,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat bubble widget ──────────────────────────
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.fontFamily,
    required this.onDelete,
  });

  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final String fontFamily;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bgColor = isMe
        ? RihlaColors.jungleGreen.withValues(alpha: 0.85)
        : (isDark ? RihlaColors.darkCard : Colors.white);
    final textColor = isMe
        ? Colors.white
        : (isDark ? RihlaColors.darkText : RihlaColors.jungleGreenDark);
    final nameColor = isMe ? Colors.white70 : RihlaColors.sunsetOrange;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDelete,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(message.senderName,
                      style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: nameColor)),
                ),
              if (message.isPhoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.imageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: RihlaColors.sunsetOrange)),
                      );
                    },
                  ),
                ),
              if (message.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: message.isPhoto ? 8 : 0),
                  child: Text(message.text,
                      style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 15,
                          color: textColor)),
                ),
              const SizedBox(height: 4),
              Text(
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style:
                    TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
