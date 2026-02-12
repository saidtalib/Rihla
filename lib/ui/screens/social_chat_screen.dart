import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../../services/chat_service.dart';
import '../../services/trip_service.dart';

/// Full-featured social chat with avatars, PDF support, and vault sync.
/// Web-safe: uses bytes-based uploads, no dart:io.
class SocialChatScreen extends StatefulWidget {
  const SocialChatScreen(
      {super.key, required this.trip, required this.onTripUpdated});
  final Trip trip;
  final ValueChanged<Trip> onTripUpdated;

  @override
  State<SocialChatScreen> createState() => _SocialChatScreenState();
}

class _SocialChatScreenState extends State<SocialChatScreen>
    with AutomaticKeepAliveClientMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _uploading = false;

  @override
  bool get wantKeepAlive => true;

  String get _myUid => TripService.instance.currentUserId;
  bool get _isAdmin => TripService.instance.currentUserIsAdmin(widget.trip);

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await ChatService.instance.sendText(widget.trip.id, text);
    _scrollToBottom();
  }

  Future<void> _showAttachmentMenu() async {
    final ar = AppSettings.of(context).isArabic;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.photo_rounded, color: Colors.white),
              ),
              title: Text(ar ? 'صورة من المعرض' : 'Photo from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                child:
                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              ),
              title: Text(ar ? 'ملف PDF' : 'PDF Document'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;

    setState(() => _uploading = true);
    try {
      await ChatService.instance.sendPhoto(
        widget.trip.id,
        picked.bytes!,
        picked.name,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;

    setState(() => _uploading = true);
    try {
      await ChatService.instance.sendPdf(
        widget.trip.id,
        picked.bytes!,
        picked.name,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    final ar = AppSettings.of(context).isArabic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'حذف الرسالة؟' : 'Delete message?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'حذف' : 'Delete',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await ChatService.instance.deleteMessage(
      widget.trip.id,
      msg,
      isAdminUser: _isAdmin,
    );
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ar
                ? 'لا يمكنك حذف هذه الرسالة'
                : 'You can only delete your own messages'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final cs = Theme.of(context).colorScheme;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.instance.messagesStream(widget.trip.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(color: cs.primary));
              }
              final messages = snap.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: cs.primary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        ar
                            ? 'لا توجد رسائل بعد. ابدأ المحادثة!'
                            : 'No messages yet. Start chatting!',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == _myUid;
                  final canDelete = isMe || _isAdmin;
                  return _ChatBubble(
                    message: msg,
                    isMe: isMe,
                    isDark: dark,
                    fontFamily: fontFamily!,
                    canDelete: canDelete,
                    onDelete: () => _deleteMessage(msg),
                    onOpenFile:
                        msg.hasFile ? () => _openFile(msg.fileUrl!) : null,
                  );
                },
              );
            },
          ),
        ),
        if (_uploading)
          LinearProgressIndicator(
            color: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        _buildInputBar(ar, dark, fontFamily!, cs),
      ],
    );
  }

  Widget _buildInputBar(
      bool ar, bool dark, String fontFamily, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? cs.surface,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.add_circle_rounded,
                    color: cs.primary, size: 28),
            onPressed: _uploading ? null : _showAttachmentMenu,
          ),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(fontSize: 15, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: ar ? 'اكتب رسالة...' : 'Type a message...',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: dark
                    ? cs.surfaceContainerHighest
                    : cs.surfaceContainerLowest,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            backgroundColor: cs.primary,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
              onPressed: _send,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════
//  Chat Bubble Widget
// ═════════════════════════════════════════════════
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.fontFamily,
    required this.canDelete,
    required this.onDelete,
    this.onOpenFile,
  });

  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final String fontFamily;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = isMe
        ? cs.primary.withValues(alpha: 0.85)
        : (isDark ? cs.surfaceContainerHighest : cs.surfaceContainerLowest);
    final textColor = isMe ? Colors.white : cs.onSurface;
    final nameColor = isMe ? Colors.white70 : cs.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(cs),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: canDelete ? onDelete : null,
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
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
                    if (message.isPhoto && message.fileUrl != null)
                      GestureDetector(
                        onTap: onOpenFile,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.fileUrl!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: 200,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: cs.primary)),
                              );
                            },
                            errorBuilder: (_, e, st) => Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Center(
                                  child: Icon(Icons.broken_image_rounded,
                                      size: 40, color: Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                    if (message.isPdf)
                      GestureDetector(
                        onTap: onOpenFile,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isMe ? Colors.white : cs.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded,
                                  color: isMe ? Colors.white : cs.primary,
                                  size: 32),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.fileName ?? 'Document.pdf',
                                      style: TextStyle(
                                        fontFamily: fontFamily,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text('PDF',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: textColor
                                                .withValues(alpha: 0.5))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.open_in_new_rounded,
                                  size: 18,
                                  color: textColor.withValues(alpha: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    if (message.text.isNotEmpty)
                      Padding(
                        padding:
                            EdgeInsets.only(top: message.hasFile ? 8 : 0),
                        child: Text(message.text,
                            style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 15,
                                color: textColor)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar(cs),
        ],
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    final photoUrl = message.senderPhotoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: cs.surfaceContainerHighest,
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor:
          isMe ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerHighest,
      child: Icon(Icons.person_rounded,
          size: 18, color: isMe ? cs.primary : cs.onSurfaceVariant),
    );
  }
}
