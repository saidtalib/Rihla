import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/chat_service.dart';
import '../../services/trip_service.dart';

/// Tab 4: Vault — gallery of all files (images + PDFs) synced from chat.
class VaultTab extends StatefulWidget {
  const VaultTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool get _isAdmin => TripService.instance.currentUserIsAdmin(widget.trip);
  String get _myUid => TripService.instance.currentUserId;

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteVaultItem(Map<String, dynamic> item) async {
    final ar = AppSettings.of(context).isArabic;
    final uploaderId = item['uploaded_by_id'] as String? ?? '';
    if (uploaderId != _myUid && !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar
              ? 'لا يمكنك حذف ملفات الآخرين'
              : 'You can only delete your own files'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'حذف الملف؟' : 'Delete file?'),
        content: Text(ar
            ? 'لا يمكن التراجع عن هذا الإجراء.'
            : 'This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Delete from vault sub-collection
    final docId = item['id'] as String?;
    if (docId != null) {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.trip.id)
          .collection('vault')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChatService.instance.vaultStream(widget.trip.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: RihlaColors.jungleGreen));
        }

        final items = snap.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_rounded,
                    size: 64,
                    color: RihlaColors.sunsetOrange.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  ar ? 'الخزنة فارغة' : 'Vault is empty',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 18,
                      color: dark
                          ? RihlaColors.darkText
                          : RihlaColors.jungleGreen),
                ),
                const SizedBox(height: 8),
                Text(
                  ar
                      ? 'الملفات المرسلة في الدردشة تظهر هنا تلقائيًا'
                      : 'Files sent in chat appear here automatically',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      color: (dark
                              ? RihlaColors.darkText
                              : RihlaColors.jungleGreenDark)
                          .withValues(alpha: 0.5)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Separate images and PDFs
        final images =
            items.where((i) => i['file_type'] == 'image').toList();
        final pdfs = items.where((i) => i['file_type'] == 'pdf').toList();

        return CustomScrollView(
          slivers: [
            // ── Images section ─────────────────
            if (images.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_rounded,
                          color: RihlaColors.sunsetOrange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        ar
                            ? 'الصور (${images.length})'
                            : 'Photos (${images.length})',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? RihlaColors.saharaSand
                              : RihlaColors.jungleGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                        _buildImageTile(images[i], dark, fontFamily!),
                    childCount: images.length,
                  ),
                ),
              ),
            ],

            // ── PDFs section ───────────────────
            if (pdfs.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded,
                          color: RihlaColors.sunsetOrange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        ar
                            ? 'مستندات PDF (${pdfs.length})'
                            : 'PDF Documents (${pdfs.length})',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? RihlaColors.saharaSand
                              : RihlaColors.jungleGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) =>
                      _buildPdfTile(pdfs[i], dark, fontFamily!, ar),
                  childCount: pdfs.length,
                ),
              ),
            ],

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        );
      },
    );
  }

  Widget _buildImageTile(
      Map<String, dynamic> item, bool dark, String fontFamily) {
    final url = item['file_url'] as String? ?? '';
    final uploaderName = item['uploaded_by_name'] as String? ?? '';

    return GestureDetector(
      onTap: () => _openFullScreen(url, uploaderName),
      onLongPress: () => _deleteVaultItem(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: dark
                      ? RihlaColors.darkCard
                      : RihlaColors.saharaSandDark,
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: RihlaColors.sunsetOrange, strokeWidth: 2)),
                );
              },
              errorBuilder: (_, e, st) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Text(
                  uploaderName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfTile(
      Map<String, dynamic> item, bool dark, String fontFamily, bool ar) {
    final url = item['file_url'] as String? ?? '';
    final fileName = item['file_name'] as String? ?? 'Document.pdf';
    final uploaderName = item['uploaded_by_name'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: RihlaColors.sunsetOrange.withValues(alpha: 0.12),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: RihlaColors.sunsetOrange),
          ),
          title: Text(
            fileName,
            style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            uploaderName,
            style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 12,
                color: (dark
                        ? RihlaColors.darkText
                        : RihlaColors.jungleGreenDark)
                    .withValues(alpha: 0.5)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded,
                    color: RihlaColors.jungleGreen),
                onPressed: () => _openFile(url),
                tooltip: ar ? 'فتح' : 'Open',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20),
                onPressed: () => _deleteVaultItem(item),
                tooltip: ar ? 'حذف' : 'Delete',
              ),
            ],
          ),
          onTap: () => _openFile(url),
        ),
      ),
    );
  }

  void _openFullScreen(String url, String uploaderName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenPhoto(imageUrl: url, uploaderName: uploaderName),
      ),
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto(
      {required this.imageUrl, required this.uploaderName});
  final String imageUrl;
  final String uploaderName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(uploaderName, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
