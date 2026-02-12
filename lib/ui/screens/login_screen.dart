import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../services/auth_service.dart';
import '../../ui/theme/app_theme.dart';

/// Login screen with Google, Apple, and Email/Password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  // Email mode
  bool _showEmailForm = false;
  bool _isSignUp = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithApple();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _emailAuth() async {
    final ar = AppSettings.of(context).isArabic;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = ar
          ? 'أدخل البريد الإلكتروني وكلمة المرور'
          : 'Enter email and password');
      return;
    }

    if (_isSignUp && pass != _confirmPassCtrl.text) {
      setState(
          () => _error = ar ? 'كلمات المرور غير متطابقة' : 'Passwords don\'t match');
      return;
    }

    if (_isSignUp && pass.length < 6) {
      setState(() => _error = ar
          ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
          : 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await AuthService.instance.signUpWithEmail(email, pass);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ar
                  ? 'تم إرسال رابط التحقق إلى بريدك'
                  : 'Verification email sent!'),
              backgroundColor: R.success,
            ),
          );
        }
      } else {
        await AuthService.instance.signInWithEmail(email, pass);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e.toString(), ar));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final ar = AppSettings.of(context).isArabic;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = ar
          ? 'أدخل بريدك الإلكتروني أولاً'
          : 'Enter your email first');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ar
                ? 'تم إرسال رابط إعادة تعيين كلمة المرور'
                : 'Password reset email sent!'),
            backgroundColor: R.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  String _friendlyError(String error, bool ar) {
    if (error.contains('user-not-found')) {
      return ar ? 'لا يوجد حساب بهذا البريد' : 'No account found with this email';
    }
    if (error.contains('wrong-password') || error.contains('invalid-credential')) {
      return ar ? 'كلمة المرور غير صحيحة' : 'Incorrect password';
    }
    if (error.contains('email-already-in-use')) {
      return ar ? 'البريد الإلكتروني مستخدم بالفعل' : 'Email already in use';
    }
    if (error.contains('invalid-email')) {
      return ar ? 'بريد إلكتروني غير صالح' : 'Invalid email address';
    }
    return error;
  }

  bool get _showApple {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text('🌍', style: const TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rihla',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ar
                        ? 'خطط رحلتك مع أصدقائك'
                        : 'Plan trips with your crew',
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (!_showEmailForm) ...[
                    // ── Social buttons ─────────────
                    _SocialButton(
                      icon: Icons.g_mobiledata_rounded,
                      label: ar ? 'تسجيل بحساب Google' : 'Continue with Google',
                      color: cs.onSurface,
                      onTap: _loading ? null : _googleSignIn,
                    ),
                    if (_showApple) ...[
                      const SizedBox(height: 12),
                      _SocialButton(
                        icon: Icons.apple_rounded,
                        label: ar ? 'تسجيل بحساب Apple' : 'Continue with Apple',
                        color: cs.onSurface,
                        onTap: _loading ? null : _appleSignIn,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: cs.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(ar ? 'أو' : 'or',
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
                        ),
                        Expanded(child: Divider(color: cs.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _showEmailForm = true),
                        icon: const Icon(Icons.email_outlined),
                        label: Text(ar
                            ? 'تسجيل بالبريد الإلكتروني'
                            : 'Continue with Email'),
                      ),
                    ),
                  ] else ...[
                    // ── Email form ─────────────────
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: ar ? 'البريد الإلكتروني' : 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      textInputAction:
                          _isSignUp ? TextInputAction.next : TextInputAction.go,
                      onSubmitted: _isSignUp ? null : (_) => _emailAuth(),
                      decoration: InputDecoration(
                        labelText: ar ? 'كلمة المرور' : 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPassCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _emailAuth(),
                        decoration: InputDecoration(
                          labelText: ar
                              ? 'تأكيد كلمة المرور'
                              : 'Confirm Password',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!_isSignUp)
                      Align(
                        alignment:
                            ar ? Alignment.centerLeft : Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(ar
                              ? 'نسيت كلمة المرور؟'
                              : 'Forgot password?'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _emailAuth,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_isSignUp
                                ? (ar ? 'إنشاء حساب' : 'Create Account')
                                : (ar ? 'تسجيل الدخول' : 'Sign In')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? (ar ? 'لديك حساب؟' : 'Already have an account?')
                              : (ar ? 'ليس لديك حساب؟' : 'Don\'t have an account?'),
                          style: tt.bodySmall,
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                          }),
                          child: Text(_isSignUp
                              ? (ar ? 'تسجيل الدخول' : 'Sign In')
                              : (ar ? 'إنشاء حساب' : 'Sign Up')),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showEmailForm = false),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(ar ? 'رجوع' : 'Back'),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: R.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(R.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: R.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: tt.bodySmall
                                    ?.copyWith(color: R.error)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(color: cs.primary),
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 24),
        label: Text(label,
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(R.radiusMd),
          ),
        ),
      ),
    );
  }
}
