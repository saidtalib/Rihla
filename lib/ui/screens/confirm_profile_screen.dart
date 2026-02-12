import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../ui/theme/app_theme.dart';

/// Onboarding screen after login — confirm or set display name & photo.
class ConfirmProfileScreen extends StatefulWidget {
  const ConfirmProfileScreen({super.key});

  @override
  State<ConfirmProfileScreen> createState() => _ConfirmProfileScreenState();
}

class _ConfirmProfileScreenState extends State<ConfirmProfileScreen> {
  final _nameCtrl = TextEditingController();
  Uint8List? _pickedBytes;
  String? _existingPhotoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
    _existingPhotoUrl = user?.photoURL;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    setState(() {
      _pickedBytes = bytes;
      _existingPhotoUrl = null; // show picked instead
    });
  }

  Future<void> _save() async {
    final ar = AppSettings.of(context).isArabic;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'أدخل اسمك' : 'Enter your name'),
          backgroundColor: R.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? photoUrl;
      if (_pickedBytes != null) {
        photoUrl =
            await ChatService.instance.uploadProfilePhoto(_pickedBytes!);
      }

      await AuthService.instance.updateProfile(
        displayName: name,
        photoUrl: photoUrl ?? _existingPhotoUrl,
      );

      // Auth state listener in main.dart will navigate away
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: R.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;
    final isEmailUser = user?.providerData
            .any((p) => p.providerId == 'password') ??
        false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  Text(
                    ar ? 'أكمل ملفك الشخصي' : 'Complete Your Profile',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEmailUser
                        ? (ar
                            ? 'أضف اسمك وصورتك الشخصية'
                            : 'Add your name and profile photo')
                        : (ar
                            ? 'تأكد من معلوماتك أو قم بتحديثها'
                            : 'Confirm or update your info'),
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Avatar
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: cs.surfaceContainerHighest,
                          backgroundImage: _pickedBytes != null
                              ? MemoryImage(_pickedBytes!)
                              : (_existingPhotoUrl != null &&
                                      _existingPhotoUrl!.isNotEmpty
                                  ? NetworkImage(_existingPhotoUrl!)
                                      as ImageProvider
                                  : null),
                          child: (_pickedBytes == null &&
                                  (_existingPhotoUrl == null ||
                                      _existingPhotoUrl!.isEmpty))
                              ? Icon(Icons.person_rounded,
                                  size: 48, color: cs.onSurfaceVariant)
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
                              border:
                                  Border.all(color: cs.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _pickPhoto,
                    child: Text(ar
                        ? (_existingPhotoUrl != null
                            ? 'تغيير الصورة'
                            : 'إضافة صورة')
                        : (_existingPhotoUrl != null
                            ? 'Change Photo'
                            : 'Upload Photo')),
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: ar ? 'الاسم الكامل' : 'Display Name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 8),
                  if (user?.email != null && user!.email!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            user.email!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              ar ? 'متابعة' : 'Continue',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
