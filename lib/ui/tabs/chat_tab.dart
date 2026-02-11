import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/chat_service.dart';
import '../../services/trip_service.dart';

/// Tab 2: WhatsApp-style chat — text + photos via Firestore.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with AutomaticKeepAliveClientMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  bool _sending = false;

  @override
  bool get wantKeepAlive => true;

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await ChatService.instance.sendText(widget.trip.id, text);
    _scrollToBottom();
  }

  Future<void> _pickAndSendPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
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

  Future<void> _deleteMessage(ChatMessage msg) async {
    final isAdmin = TripService.instance.currentUserIsAdmin(widget.trip);
    final deleted = await ChatService.instance.deleteMessage(
      widget.trip.id, msg, isAdminUser: isAdmin,
    );
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot delete this message'), backgroundColor: Colors.red),
      );
    }
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
    final myUid = TripService.instance.currentUserId;

    return Column(
      children: [
        // ── Messages ──────────────────────────
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.instance.messagesStream(widget.trip.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: RihlaColors.jungleGreen));
              }
              final messages = snap.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    ar ? 'لا توجد رسائل بعد. ابدأ المحادثة!' : 'No messages yet. Start chatting!',
                    style: TextStyle(fontFamily: fontFamily, color: (dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark).withValues(alpha: 0.5)),
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
                  final isMe = msg.senderId == myUid;
                  return _ChatBubble(
                    message: msg,
                    isMe: isMe,
                    isDark: dark,
                    fontFamily: fontFamily!,
                    onDelete: () => _deleteMessage(msg),
                  );
                },
              );
            },
          ),
        ),

        // ── Input bar ─────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: dark ? RihlaColors.darkCard : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              // Photo button
              IconButton(
                icon: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.photo_camera_rounded, color: RihlaColors.sunsetOrange),
                onPressed: _sending ? null : _pickAndSendPhoto,
              ),
              // Text input
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: TextStyle(fontSize: 15, color: dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark),
                  decoration: InputDecoration(
                    hintText: ar ? 'اكتب رسالة...' : 'Type a message...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: dark ? RihlaColors.darkSurface : RihlaColors.saharaSand,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Send button
              CircleAvatar(
                backgroundColor: RihlaColors.jungleGreen,
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Chat bubble widget ──────────────────────

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
    final nameColor = isMe
        ? Colors.white70
        : RihlaColors.sunsetOrange;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDelete,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(message.senderName,
                      style: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: nameColor)),
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
                        child: Center(child: CircularProgressIndicator(color: RihlaColors.sunsetOrange)),
                      );
                    },
                  ),
                ),
              if (message.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: message.isPhoto ? 8 : 0),
                  child: Text(message.text,
                      style: TextStyle(fontFamily: fontFamily, fontSize: 15, color: textColor)),
                ),
              const SizedBox(height: 4),
              Text(
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
