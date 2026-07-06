import 'package:flutter/material.dart';

/// Confirms leaving the stream studio before going live.
Future<bool?> showLeaveStreamStudioDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Leave Stream Studio?'),
      content: const Text(
        'You have not started a live stream yet.\n'
        'Do you want to leave the studio or stay to set up your broadcast?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
}
