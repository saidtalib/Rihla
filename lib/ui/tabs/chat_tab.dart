import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/error_toast.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/ai_service.dart';
import '../../services/chat_service.dart';
import '../../services/trip_service.dart';

/// Tab 2: WhatsApp-style chat — text + photos via Firestore; plus Trip Assistant (AI revisions).
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

/// One entry in the Trip Assistant conversation (user message or AI reply with optional revised plan).
class _AssistantEntry {
  final bool isUser;
  final String text;
  final AiTripResult? revisedResult;

  _AssistantEntry({required this.isUser, required this.text, this.revisedResult});
}

class _ChatTabState extends State<ChatTab> with AutomaticKeepAliveClientMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  // Trip Assistant: segment (false = Group Chat, true = Trip Assistant)
  bool _tripAssistantMode = false;
  final List<_AssistantEntry> _assistantEntries = [];
  bool _assistantLoading = false;
  final _assistantScrollCtrl = ScrollController();
  final _assistantInputCtrl = TextEditingController();
  AiTripResult? _pendingRevisedResult; // last revised plan from AI (for multi-turn + Apply)
  bool _assistantApplied = false; // true after user taps Apply once

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;
    setState(() => _sending = true);
    try {
      await ChatService.instance.sendPhoto(widget.trip.id, picked.bytes!, picked.name);
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

  /// Build a text summary of the current trip for the AI (from Firestore trip or last revised result).
  String _tripSummaryForAi() {
    if (_pendingRevisedResult != null) {
      final r = _pendingRevisedResult!;
      final dates =
          '${r.tripStartDate ?? '?'} to ${r.tripEndDate ?? '?'}';
      final itinerary =
          r.dailyItinerary.take(10).join('\n');
      final locations = r.locations.map((l) => l.name).join(', ');
      return 'Title: ${r.tripTitle}\nDates: $dates\nLocations: $locations\nItinerary:\n$itinerary';
    }
    final t = widget.trip;
    final dates = t.startDate != null && t.endDate != null
        ? '${t.startDate!.year}-${t.startDate!.month.toString().padLeft(2, '0')}-${t.startDate!.day.toString().padLeft(2, '0')} to ${t.endDate!.year}-${t.endDate!.month.toString().padLeft(2, '0')}-${t.endDate!.day.toString().padLeft(2, '0')}'
        : 'Not set';
    final itinerary = t.itinerary.take(10).join('\n');
    final locations = t.locations.map((l) => l.name).join(', ');
    return 'Title: ${t.title}\nDates: $dates\nLocations: $locations\nItinerary:\n$itinerary';
  }

  Future<void> _sendToAssistant() async {
    final text = _assistantInputCtrl.text.trim();
    if (text.isEmpty || _assistantLoading) return;
    _assistantInputCtrl.clear();

    setState(() {
      _assistantEntries.add(_AssistantEntry(isUser: true, text: text));
      _assistantLoading = true;
    });
    _scrollAssistantToBottom();

    final ar = AppSettings.of(context).isArabic;

    try {
      final summary = _tripSummaryForAi();
      final result = await AiService.instance.reviseTrip(
        currentTripSummary: summary,
        userMessage: text,
        isArabic: ar,
      );
      if (!mounted) return;
      setState(() {
        _assistantEntries.add(_AssistantEntry(
          isUser: false,
          text: result.tripTitle,
          revisedResult: result,
        ));
        _pendingRevisedResult = result;
        _assistantLoading = false;
      });
      _scrollAssistantToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _assistantLoading = false);
      ErrorToast.show(
        context,
        ar ? 'تعذر تحديث الخطة. تحقق من اتصالك.' : 'Could not revise plan. Check your connection.',
        isArabic: ar,
      );
    }
  }

  void _scrollAssistantToBottom() {
    if (_assistantScrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_assistantScrollCtrl.hasClients) {
          _assistantScrollCtrl.animateTo(
            _assistantScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _applyRevisedTrip() async {
    if (_pendingRevisedResult == null) return;
    final ar = AppSettings.of(context).isArabic;
    setState(() => _assistantLoading = true);
    try {
      await TripService.instance.updateFromAiResult(
        widget.trip.id,
        _pendingRevisedResult!,
      );
      if (!mounted) return;
      setState(() {
        _assistantLoading = false;
        _assistantApplied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ar ? 'تم تطبيق التعديلات على الرحلة' : 'Changes applied to your trip',
          ),
          backgroundColor: RihlaColors.jungleGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _assistantLoading = false);
      ErrorToast.show(
        context,
        ar ? 'فشل تطبيق التعديلات' : 'Failed to apply changes',
        isArabic: ar,
      );
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _assistantScrollCtrl.dispose();
    _assistantInputCtrl.dispose();
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
        // ── Segment: Group Chat | Trip Assistant ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: Text(ar ? 'المحادثة' : 'Chat'),
                selected: !_tripAssistantMode,
                onSelected: (v) => setState(() => _tripAssistantMode = false),
                selectedColor: RihlaColors.jungleGreen.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(ar ? 'مساعد الرحلة' : 'Trip Assistant'),
                selected: _tripAssistantMode,
                onSelected: (v) => setState(() => _tripAssistantMode = true),
                selectedColor: RihlaColors.jungleGreen.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),

        // ── Body: Trip Assistant or Group Chat ──
        if (_tripAssistantMode) ...[
          // Trip summary card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Card(
              color: dark ? RihlaColors.darkCard : RihlaColors.saharaSand,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.trip.title,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontWeight: FontWeight.w700,
                        color: dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ar
                          ? 'اطلب تعديلات مثل: "اجعله أرخص" أو "أضف مشيًا أكثر"'
                          : 'Ask for changes like: "make it cheaper" or "add more hiking"',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 12,
                        color: (dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Assistant messages
          Expanded(
            child: ListView.builder(
              controller: _assistantScrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _assistantEntries.length + (_assistantLoading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_assistantLoading && i == _assistantEntries.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 18, color: RihlaColors.sunsetOrange),
                        const SizedBox(width: 8),
                        Text(
                          ar ? 'جاري تحديث الخطة...' : 'Revising plan...',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 13,
                            color: (dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final entry = _assistantEntries[i];
                final isUser = entry.isUser;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? RihlaColors.jungleGreen.withValues(alpha: 0.85)
                          : (dark ? RihlaColors.darkCard : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.text,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 14,
                            color: isUser ? Colors.white : (dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark),
                          ),
                        ),
                        if (entry.revisedResult != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            ar ? 'تم تحديث الخطة. طبّق التعديلات؟' : 'Plan updated. Apply changes?',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 12,
                              color: (dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark).withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: _assistantLoading || _assistantApplied ? null : _applyRevisedTrip,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(ar ? 'تطبيق على الرحلة' : 'Apply to trip'),
                            style: TextButton.styleFrom(
                              foregroundColor: RihlaColors.jungleGreen,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Assistant input bar
          Container(
            padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: dark ? RihlaColors.darkCard : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _assistantInputCtrl,
                    enabled: !_assistantLoading,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendToAssistant(),
                    style: TextStyle(
                      fontSize: 15,
                      color: dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark,
                    ),
                    decoration: InputDecoration(
                      hintText: ar ? 'اطلب تعديلاً...' : 'Ask for a change...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: dark ? RihlaColors.darkSurface : RihlaColors.saharaSand,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: RihlaColors.jungleGreen,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _assistantLoading ? null : _sendToAssistant,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
        // ── Messages (Group Chat) ──────────────────────────
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
                    message.fileUrl!,
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
