import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../services/auth_service.dart';
import 'account_screen.dart';
import 'support_screen.dart';

/// Full settings hub: Account (sub-screen), Support, Preferences, Notifications.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final data = settings.data;
    final ar = settings.isArabic;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'الإعدادات' : 'Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ═════════════════════════════════════════
          //  ACCOUNT (sub-screen)
          // ═════════════════════════════════════════
          _SectionHeader(
              label: ar ? 'الحساب' : 'Account', icon: Icons.person_rounded),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.person_rounded, color: cs.onSurface.withValues(alpha: 0.7)),
            title: Text(ar ? 'الملف الشخصي والسلامة' : 'Profile & safety'),
            subtitle: Text(ar ? 'الاسم، الصورة، حذف الحساب' : 'Name, photo, delete account'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),
          const SizedBox(height: 16),

          // ═════════════════════════════════════════
          //  SUPPORT
          // ═════════════════════════════════════════
          ListTile(
            leading: Icon(Icons.support_rounded, color: cs.onSurface.withValues(alpha: 0.7)),
            title: Text(ar ? 'الدعم' : 'Support'),
            subtitle: Text(ar ? 'إرسال ملاحظات أو طلب مساعدة' : 'Send feedback or get help'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // ═════════════════════════════════════════
          //  PREFERENCES SECTION
          // ═════════════════════════════════════════
          _SectionHeader(
              label: ar ? 'التفضيلات' : 'Preferences',
              icon: Icons.tune_rounded),
          const SizedBox(height: 12),

          // Language
          _PreferenceRow(
            label: ar ? 'اللغة' : 'Language',
            icon: Icons.language_rounded,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('EN')),
                ButtonSegment(value: true, label: Text('عربي')),
              ],
              selected: {data.isArabic},
              onSelectionChanged: (v) {
                data.setArabic(v.first);
                settings.onChanged();
              },
            ),
          ),
          const SizedBox(height: 4),

          // Theme
          _PreferenceRow(
            label: ar ? 'المظهر' : 'Theme',
            icon: Icons.palette_rounded,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(ar ? 'تلقائي' : 'Auto',
                        style: const TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(ar ? 'فاتح' : 'Light',
                        style: const TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(ar ? 'داكن' : 'Dark',
                        style: const TextStyle(fontSize: 12))),
              ],
              selected: {data.themeMode},
              onSelectionChanged: (v) {
                data.setThemeMode(v.first);
                settings.onChanged();
              },
            ),
          ),
          const SizedBox(height: 4),

          // Units
          SwitchListTile(
            secondary: const Icon(Icons.straighten_rounded),
            title: Text(ar ? 'الوحدات' : 'Units'),
            subtitle: Text(data.useMetric
                ? (ar ? 'متري (كم / °م)' : 'Metric (km / °C)')
                : (ar ? 'إمبراطوري (ميل / °ف)' : 'Imperial (mi / °F)')),
            value: data.useMetric,
            onChanged: (v) {
              data.setUseMetric(v);
              settings.onChanged();
              setState(() {});
            },
          ),

          // Date format
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today_rounded),
            title: Text(ar ? 'تنسيق التاريخ' : 'Date Format'),
            subtitle: Text(data.useDDMMYYYY ? 'DD/MM/YYYY' : 'MM/DD/YYYY'),
            value: data.useDDMMYYYY,
            onChanged: (v) {
              data.setUseDDMMYYYY(v);
              settings.onChanged();
              setState(() {});
            },
          ),
          const SizedBox(height: 24),

          // ═════════════════════════════════════════
          //  NOTIFICATION CENTER
          // ═════════════════════════════════════════
          _SectionHeader(
            label: ar ? 'مركز الإشعارات' : 'Notification Center',
            icon: Icons.notifications_rounded,
          ),
          const SizedBox(height: 8),
          Text(
            ar
                ? 'اختر الإشعارات التي تريد تلقيها'
                : 'Choose which notifications you receive',
            style: tt.bodySmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 8),

          _NotifSwitch(
            icon: Icons.chat_bubble_rounded,
            label: ar ? 'رسالة جديدة (العزوة)' : 'New Chat Message (Pack)',
            value: data.notifChat,
            onChanged: (v) {
              data.setNotifChat(v);
              settings.onChanged();
              setState(() {});
            },
          ),
          _NotifSwitch(
            icon: Icons.monetization_on_rounded,
            label: ar ? 'مصروف جديد (الجطية)' : 'New Expense Added (Kitty)',
            value: data.notifExpense,
            onChanged: (v) {
              data.setNotifExpense(v);
              settings.onChanged();
              setState(() {});
            },
          ),
          _NotifSwitch(
            icon: Icons.route_rounded,
            label: ar ? 'تحديث الخطة' : 'Plan Updated (Trip Details)',
            value: data.notifPlan,
            onChanged: (v) {
              data.setNotifPlan(v);
              settings.onChanged();
              setState(() {});
            },
          ),
          _NotifSwitch(
            icon: Icons.photo_library_rounded,
            label: ar ? 'ملف/صورة جديدة (الخزنة)' : 'New Photo/Doc (Vault)',
            value: data.notifVault,
            onChanged: (v) {
              data.setNotifVault(v);
              settings.onChanged();
              setState(() {});
            },
          ),
          const SizedBox(height: 32),

          // ═════════════════════════════════════════
          //  SIGN OUT
          // ═════════════════════════════════════════
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurface,
                side: BorderSide(color: cs.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(ar ? 'تسجيل خروج' : 'Sign Out'),
              onPressed: () {
                AuthService.instance.signOut();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Section header ───────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(label,
            style: tt.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
      ],
    );
  }
}

// ── Preference row with trailing widget ──────────
class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.icon,
    required this.child,
  });
  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: tt.bodyMedium),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Notification switch tile ─────────────────────
class _NotifSwitch extends StatelessWidget {
  const _NotifSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }
}
