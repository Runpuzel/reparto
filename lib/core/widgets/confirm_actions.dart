import 'package:flutter/material.dart';

import '../utils/app_error.dart';

/// Reusable helpers for confirmation dialogs, undoable actions and consistent
/// Success and error feedback across UjustBUY.
class ConfirmActions {
  /// Shows a confirmation dialog. Returns true if the user confirms.
  static Future<bool> confirm(
      BuildContext context, {
        required String title,
        required String message,
        String confirmLabel = 'Confirm',
        String cancelLabel = 'Cancel',
        IconData? icon,
        bool destructive = false,
      }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon != null
            ? Icon(icon,
            size: 40,
            color: destructive ? scheme.error : scheme.primary)
            : null,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: scheme.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a snackbar with an Undo action. [onUndo] runs if the user taps Undo
  /// before the snackbar is dismissed. Returns true if undo was triggered.
  static Future<bool> showUndo(
      BuildContext context, {
        required String message,
        VoidCallback? onUndo,
        Duration duration = const Duration(seconds: 4),
      }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Undo', onPressed: onUndo ?? () {}),
      ),
    );
    final reason = await controller.closed;
    return reason == SnackBarClosedReason.action;
  }

  /// Lightweight success / info feedback.
  static void toast(BuildContext context, String message, {bool success = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: success ? Colors.green.shade700 : null,
        showCloseIcon: true,
      ));
  }

  /// Shows a user-friendly error message derived from any thrown error.
  static void showError(BuildContext context, Object? error) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(AppError.friendly(error)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.error,
        showCloseIcon: true,
        duration: const Duration(seconds: 4),
      ));
  }
}
