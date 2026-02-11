import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/chat_service.dart';
import '../../services/trip_service.dart';

/// Tab 3: Photo vault — auto-synced from chat photos.
/// Users can delete own photos; admins can delete any.
class VaultTab extends StatefulWidget {
  const VaultTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _deletePhoto(ChatMessage photoMsg) async {
    final ar = AppSettings.of(context).isArabic;
    final isAdmin = TripService.instance.currentUserIsAdmin(widget.trip);
    final myUid = TripService.instance.currentUserId;

    // Check permission
    if (photoMsg.senderId != myUid && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'لا يمكنك حذف صور الآخرين' : 'You can only delete your own photos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'حذف الصورة؟' : 'Delete photo?'),
        content: Text(ar ? 'لا يمكن التراجع عن هذا الإجراء.' : 'This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ChatService.instance.deleteMessage(
      widget.trip.id,
      photoMsg,
      isAdminUser: isAdmin,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    return StreamBuilder<List<ChatMessage>>(
      stream: ChatService.instance.photosStream(widget.trip.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: RihlaColors.jungleGreen));
        }

        final photos = snap.data ?? [];

        if (photos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_rounded, size: 64, color: RihlaColors.sunsetOrange.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  ar ? 'لا توجد صور بعد' : 'No photos yet',
                  style: TextStyle(fontFamily: fontFamily, fontSize: 18, color: dark ? RihlaColors.darkText : RihlaColors.jungleGreen),
                ),
                const SizedBox(height: 8),
                Text(
                  ar ? 'الصور المرسلة في الدردشة تظهر هنا تلقائيًا' : 'Photos sent in chat appear here automatically',
                  style: TextStyle(fontFamily: fontFamily, fontSize: 13, color: (dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark).withValues(alpha: 0.5)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: photos.length,
          itemBuilder: (context, i) {
            final photo = photos[i];
            return GestureDetector(
              onTap: () => _openFullScreen(photo),
              onLongPress: () => _deletePhoto(photo),
              child: Hero(
                tag: 'vault_${photo.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        photo.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: dark ? RihlaColors.darkCard : RihlaColors.saharaSandDark,
                            child: const Center(child: CircularProgressIndicator(color: RihlaColors.sunsetOrange, strokeWidth: 2)),
                          );
                        },
                      ),
                      // Sender name overlay
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                          child: Text(
                            photo.senderName,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFullScreen(ChatMessage photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPhoto(photo: photo),
      ),
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({required this.photo});
  final ChatMessage photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo.senderName, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: Hero(
          tag: 'vault_${photo.id}',
          child: InteractiveViewer(
            child: Image.network(photo.imageUrl!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
