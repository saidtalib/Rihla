import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../../services/chat_service.dart';
import '../../services/trip_service.dart';
import '../../ui/theme/app_theme.dart';

/// Tab: Vault — gallery of all files (images + PDFs) synced from chat.
class VaultTab extends StatefulWidget {
  const VaultTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Cache stream so StreamBuilder doesn't re-subscribe on every build
  late final Stream<List<Map<String, dynamic>>> _vaultStream;

  Trip get _trip => widget.trip;
  String get _myUid => TripService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _vaultStream = ChatService.instance.vaultStream(_trip.id);
  }
  bool get _isAdmin => _trip.isAdmin(_myUid);

  /// Whether the current user can delete this vault item.
  ///
  /// - Admins can delete any file.
  /// - Regular users can only delete their own files.
  bool _canDeleteItem(Map<String, dynamic> item) {
    if (_isAdmin) return true;
    final uploaderId = item['uploaded_by_id'] as String? ?? '';
    return uploaderId == _myUid;
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteVaultItem(Map<String, dynamic> item) async {
    final ar = AppSettings.of(context).isArabic;

    // Double-check permission
    if (!_canDeleteItem(item)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar
              ? 'لا يمكنك حذف ملفات الآخرين'
              : 'You can only delete your own files'),
          backgroundColor: R.error,
        ),
      );
      return;
    }

    // Confirmation dialog
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
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ar ? 'حذف' : 'Delete',
              style: const TextStyle(
                  color: R.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final docId = item['id'] as String?;
    if (docId != null) {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(_trip.id)
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _vaultStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: cs.primary),
          );
        }

        final items = snap.data ?? [];

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded,
                          size: 64,
                          color: cs.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(height: 16),
                      Text(ar ? 'الخزنة فارغة' : 'Vault is empty',
                          style: tt.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        ar
                            ? 'الملفات المرسلة في الدردشة تظهر هنا تلقائيًا'
                            : 'Files sent in chat appear here automatically',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final images =
            items.where((i) => i['file_type'] == 'image').toList();
        final pdfs = items.where((i) => i['file_type'] == 'pdf').toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: CustomScrollView(
          slivers: [
            // ── Images section ────────────────────
            if (images.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_rounded,
                          color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        ar
                            ? 'الصور (${images.length})'
                            : 'Photos (${images.length})',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                    (context, i) => _buildImageTile(images[i], cs, tt),
                    childCount: images.length,
                  ),
                ),
              ),
            ],

            // ── PDFs section ──────────────────────
            if (pdfs.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded,
                          color: R.error, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        ar
                            ? 'مستندات PDF (${pdfs.length})'
                            : 'PDF Documents (${pdfs.length})',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildPdfTile(pdfs[i], ar, cs, tt),
                  childCount: pdfs.length,
                ),
              ),
            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
            ),
          ),
        );
      },
    );
  }

  // ── Image tile ──────────────────────────────
  Widget _buildImageTile(
      Map<String, dynamic> item, ColorScheme cs, TextTheme tt) {
    final url = item['file_url'] as String? ?? '';
    final uploaderName = item['uploaded_by_name'] as String? ?? '';
    final canDelete = _canDeleteItem(item);

    return GestureDetector(
      onTap: () => _openFullScreen(url, uploaderName),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: cs.primary, strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, e, st) => Container(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image_rounded,
                    color: cs.onSurfaceVariant),
              ),
            ),
            // Uploader name overlay
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
            // Delete button — only visible if user has permission
            if (canDelete)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _deleteVaultItem(item),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── PDF tile ────────────────────────────────
  Widget _buildPdfTile(
      Map<String, dynamic> item, bool ar, ColorScheme cs, TextTheme tt) {
    final url = item['file_url'] as String? ?? '';
    final fileName = item['file_name'] as String? ?? 'Document.pdf';
    final uploaderName = item['uploaded_by_name'] as String? ?? '';
    final canDelete = _canDeleteItem(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: R.error.withValues(alpha: 0.08),
            child: const Icon(Icons.picture_as_pdf_rounded, color: R.error),
          ),
          title: Text(
            fileName,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            uploaderName,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.open_in_new_rounded, color: cs.primary),
                onPressed: () => _openFile(url),
                tooltip: ar ? 'فتح' : 'Open',
              ),
              // Delete icon — only visible if user has permission
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: R.error, size: 20),
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
