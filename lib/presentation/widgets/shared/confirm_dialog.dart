import 'package:flutter/material.dart';

/// A reusable confirmation dialog widget.
///
/// Shows a title, message, and confirm/cancel buttons.
/// Returns `true` if confirmed, `false` if cancelled.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  /// Shows the dialog and returns true if confirmed, false otherwise.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
