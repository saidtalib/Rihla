import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../ui/theme/app_theme.dart';

/// Account sub-screen: Avatar, Name, Username, Email (read-only), Save, Delete account.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _savingName = false;
  bool _savingPhoto = false;
  bool _deleting = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _user?.displayName ?? '';
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final username = await AuthService.instance.getUsername();
    if (mounted && username != null) {
      _usernameCtrl.text = username;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await AuthService.instance.updateProfile(displayName: name);
      if (username.isNotEmpty) {
        await AuthService.instance.syncUserToFirestore(
          displayName: name,
          username: username,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettings.of(context).isArabic
                  ? 'تم تحديث الملف الشخصي'
                  : 'Profile updated',
            ),
            backgroundColor: R.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: R.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changeAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final Uint8List? bytes = result.files.first.bytes;
    if (bytes == null) return;

    setState(() => _savingPhoto = true);
    try {
      final url = await ChatService.instance.uploadProfilePhoto(bytes);
      await AuthService.instance.updateProfile(
        displayName: _user?.displayName ?? _nameCtrl.text.trim(),
        photoUrl: url,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: R.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _deleteAccount() async {
    final ar = AppSettings.of(context).isArabic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: R.error, size: 40),
        title: Text(ar ? 'حذف الحساب' : 'Delete Account'),
        content: Text(
          ar
              ? 'هل أنت متأكد أنك تريد حذف حسابك نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
              : 'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: R.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'حذف نهائياً' : 'Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteAccount();
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final msg = e.code == 'requires-recent-login'
            ? (ar
                ? 'يرجى تسجيل الدخول مرة أخرى لتأكيد الحذف'
                : 'Please sign in again to confirm deletion')
            : e.message ?? e.code;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: R.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: R.error),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppSettings.of(context).isArabic;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'الحساب' : 'Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _savingPhoto ? null : _changeAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage: (_user?.photoURL != null &&
                            _user!.photoURL!.isNotEmpty)
                        ? NetworkImage(_user!.photoURL!)
                        : null,
                    child: (_user?.photoURL == null ||
                            _user!.photoURL!.isEmpty)
                        ? Icon(Icons.person_rounded,
                            size: 40, color: cs.onSurfaceVariant)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _savingPhoto
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_rounded,
                              size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: ar ? 'الاسم المعروض' : 'Display Name',
              prefixIcon: const Icon(Icons.badge_rounded, size: 20),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: ar ? 'اسم المستخدم' : 'Username',
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
              hintText: ar ? 'معرف فريد للدردشة' : 'Unique ID for chat',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveProfile(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingName ? null : _saveProfile,
              icon: _savingName
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(ar ? 'حفظ الملف الشخصي' : 'Save Profile'),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.email_rounded,
                color: cs.onSurface.withValues(alpha: 0.4), size: 20),
            title: Text(
              _user?.email ?? '',
              style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: R.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: R.error),
                    )
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text(ar ? 'حذف الحساب' : 'Delete Account'),
              onPressed: _deleting ? null : _deleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}
