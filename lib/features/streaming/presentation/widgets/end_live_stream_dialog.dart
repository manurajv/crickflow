import 'package:flutter/material.dart';

/// Confirms ending an active live stream before leaving the studio.
Future<bool?> showEndLiveStreamDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('End Live Stream?'),
      content: const Text(
        'Your live stream is still running.\n'
        'Do you want to end the live stream or continue streaming?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay Live'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('End Stream'),
        ),
      ],
    ),
  );
}
