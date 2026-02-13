import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../ui/theme/app_theme.dart';

enum SupportCategory { bug, featureRequest, general }

extension on SupportCategory {
  String get labelEn {
    switch (this) {
      case SupportCategory.bug:
        return 'Bug';
      case SupportCategory.featureRequest:
        return 'Feature Request';
      case SupportCategory.general:
        return 'General';
    }
  }

  String get labelAr {
    switch (this) {
      case SupportCategory.bug:
        return 'خطأ';
      case SupportCategory.featureRequest:
        return 'طلب ميزة';
      case SupportCategory.general:
        return 'عام';
    }
  }
}

/// Support form: Subject, Category, Message. Submits via mailto.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  SupportCategory _category = SupportCategory.general;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ar = AppSettings.of(context).isArabic;
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'أدخل الموضوع' : 'Please enter a subject'),
          backgroundColor: R.error,
        ),
      );
      return;
    }

    final categoryLabel = ar ? _category.labelAr : _category.labelEn;
    final mailSubject = '[Rihla Support - $categoryLabel] $subject';
    final mailBody = message.isEmpty ? '—' : message;

    final uri = Uri.parse(
      'mailto:Rihla@almawali.com?'
      'subject=${Uri.encodeComponent(mailSubject)}&'
      'body=${Uri.encodeComponent(mailBody)}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ar ? 'جاري فتح تطبيق البريد' : 'Opening your email app…',
              ),
              backgroundColor: R.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ar ? 'لا يمكن فتح البريد' : 'Cannot open email app'),
              backgroundColor: R.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: R.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppSettings.of(context).isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'الدعم' : 'Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          TextField(
            controller: _subjectCtrl,
            decoration: InputDecoration(
              labelText: ar ? 'الموضوع' : 'Subject',
              hintText: ar ? 'مثال: التطبيق يتوقف عند فتح الخريطة' : 'e.g. App crashes when opening map',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SupportCategory>(
            value: _category, // ignore: deprecated_member_use
            decoration: InputDecoration(
              labelText: ar ? 'التصنيف' : 'Category',
            ),
            items: SupportCategory.values.map((c) {
              return DropdownMenuItem(
                value: c,
                child: Text(ar ? c.labelAr : c.labelEn),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageCtrl,
            decoration: InputDecoration(
              labelText: ar ? 'الرسالة' : 'Message',
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Text(ar ? 'إرسال عبر البريد' : 'Send via Email'),
            ),
          ),
        ],
      ),
    );
  }
}
