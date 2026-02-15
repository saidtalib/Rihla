import 'package:flutter/material.dart';

/// User-facing error reporting: show a SnackBar instead of only debugPrint.
class ErrorToast {
  ErrorToast._();

  /// Show a red SnackBar with [message]. Use when a service/async op fails.
  static void show(
    BuildContext context,
    String message, {
    bool isArabic = false,
    String? retryLabel,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        action: (retryLabel != null && onRetry != null)
            ? SnackBarAction(
                label: retryLabel,
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
