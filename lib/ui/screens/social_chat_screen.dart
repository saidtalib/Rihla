import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../../services/chat_service.dart';
import '../../services/file_io.dart';
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
  bool _recording = false;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingAudioUrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingAudioUrl = null);
    });
  }

  String get _myUid => TripService.instance.currentUserId;
  bool get _isAdmin => TripService.instance.currentUserIsAdmin(widget.trip);

  @override
  void dispose() {
    _audioPlayer.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onPlayAudio(String? url) {
    if (url == null) return;
    if (_playingAudioUrl == url) {
      _audioPlayer.pause();
      setState(() => _playingAudioUrl = null);
    } else {
      _audioPlayer.play(UrlSource(url));
      setState(() => _playingAudioUrl = url);
    }
  }

  void _copyContact(ChatMessage msg) {
    final s = '${msg.text}\n${msg.fileName ?? ''}';
    Clipboard.setData(ClipboardData(text: s));
    final ar = AppSettings.of(context).isArabic;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ar ? 'تم النسخ' : 'Copied to clipboard')),
    );
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
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              ),
              title: Text(ar ? 'التقاط صورة' : 'Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCamera();
              },
            ),
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
                backgroundColor: Colors.green,
                child: const Icon(Icons.location_on_rounded, color: Colors.white),
              ),
              title: Text(ar ? 'مشاركة الموقع' : 'Share Location'),
              onTap: () {
                Navigator.pop(ctx);
                _shareLocation();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.amber.shade700,
                child: const Icon(Icons.contact_phone_rounded, color: Colors.white),
              ),
              title: Text(ar ? 'مشاركة جهة اتصال' : 'Share Contact'),
              onTap: () {
                Navigator.pop(ctx);
                _shareContact();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                child: Icon(
                  _recording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                ),
              ),
              title: Text(ar
                  ? (_recording ? 'إيقاف التسجيل' : 'Record Audio')
                  : (_recording ? 'Stop Recording' : 'Record Audio')),
              onTap: () {
                Navigator.pop(ctx);
                if (_recording) {
                  _stopRecording();
                } else {
                  _startRecording();
                }
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

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.camera);
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    setState(() => _uploading = true);
    try {
      await ChatService.instance.sendPhoto(
        widget.trip.id,
        bytes,
        'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
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

  Future<void> _shareLocation() async {
    final ar = AppSettings.of(context).isArabic;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ar ? 'مطلوب إذن الموقع' : 'Location permission required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      setState(() => _uploading = true);
      final pos = await Geolocator.getCurrentPosition();
      await ChatService.instance.sendLocation(
        widget.trip.id,
        pos.latitude,
        pos.longitude,
        ar ? 'موقعي' : 'My location',
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'فشل الحصول على الموقع' : 'Failed to get location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _shareContact() async {
    final ar = AppSettings.of(context).isArabic;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ar ? 'مشاركة جهة اتصال' : 'Share Contact',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: ar ? 'الاسم' : 'Name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: ar ? 'رقم الهاتف أو البريد' : 'Phone or Email',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(ar ? 'إلغاء' : 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ar ? 'أدخل الاسم' : 'Enter name'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _uploading = true);
                        try {
                          await ChatService.instance.sendContact(
                            widget.trip.id,
                            name,
                            phone,
                          );
                          _scrollToBottom();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _uploading = false);
                        }
                      },
                      child: Text(ar ? 'إرسال' : 'Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    final ar = AppSettings.of(context).isArabic;
    if (await _recorder.hasPermission()) {
      setState(() => _recording = true);
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/rihla_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'مطلوب إذن الميكروفون' : 'Microphone permission required'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (path == null || path.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final bytes = await readFileBytes(path);
      if (bytes != null && bytes.isNotEmpty) {
        await ChatService.instance.sendAudio(
          widget.trip.id,
          bytes,
          'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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

  /// Open file/URL: for PDF and image, download then open with system app chooser.
  /// For location, open maps URL in browser/app.
  Future<void> _openFile(String url, MessageType type) async {
    if (type == MessageType.location) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (type == MessageType.pdf || type == MessageType.image) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) return;
        final dir = await getTemporaryDirectory();
        final ext = type == MessageType.pdf ? 'pdf' : 'jpg';
        final path = '${dir.path}/rihla_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final ok = await writeFileBytes(path, response.bodyBytes);
        if (ok) await OpenFilex.open(path);
      } catch (_) {}
      return;
    }
    if (type == MessageType.audio) {
      // Audio is played in-bubble via audioplayers
      return;
    }
    // Fallback: open URL externally
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
                    onOpenFile: (msg.hasFile && (msg.isPdf || msg.isPhoto)) ||
                            msg.isLocation
                        ? () => _openFile(msg.fileUrl ?? '', msg.type)
                        : null,
                    onPlayAudio: msg.isAudio && msg.fileUrl != null
                        ? () => _onPlayAudio(msg.fileUrl)
                        : null,
                    playingAudioUrl: _playingAudioUrl,
                    onCopyContact:
                        msg.isContact ? () => _copyContact(msg) : null,
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
    this.onPlayAudio,
    this.playingAudioUrl,
    this.onCopyContact,
  });

  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final String fontFamily;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback? onOpenFile;
  final VoidCallback? onPlayAudio;
  final String? playingAudioUrl;
  final VoidCallback? onCopyContact;

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
                    if (message.isLocation && message.fileUrl != null)
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
                              Icon(Icons.location_on_rounded,
                                  color: isMe ? Colors.white : cs.primary,
                                  size: 28),
                              const SizedBox(width: 10),
                              Text(
                                message.text,
                                style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: 14,
                                    color: textColor),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.open_in_new_rounded,
                                  size: 16,
                                  color: textColor.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
                    if (message.isContact)
                      GestureDetector(
                        onTap: onCopyContact,
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
                              Icon(Icons.contact_phone_rounded,
                                  color: isMe ? Colors.white : cs.primary,
                                  size: 28),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.text,
                                    style: TextStyle(
                                        fontFamily: fontFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textColor),
                                  ),
                                  if (message.fileName != null &&
                                      message.fileName!.isNotEmpty)
                                    Text(
                                      message.fileName!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: textColor
                                              .withValues(alpha: 0.8)),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.copy_rounded,
                                  size: 16,
                                  color: textColor.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
                    if (message.isAudio && message.fileUrl != null)
                      GestureDetector(
                        onTap: onPlayAudio,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: (isMe ? Colors.white : cs.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                playingAudioUrl == message.fileUrl
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                color: isMe ? Colors.white : cs.primary,
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                playingAudioUrl == message.fileUrl
                                    ? (AppSettings.of(context).isArabic
                                        ? 'إيقاف'
                                        : 'Stop')
                                    : (AppSettings.of(context).isArabic
                                        ? 'تشغيل'
                                        : 'Play'),
                                style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: 14,
                                    color: textColor),
                              ),
                            ],
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
