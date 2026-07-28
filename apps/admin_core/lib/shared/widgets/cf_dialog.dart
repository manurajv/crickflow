import 'package:flutter/material.dart';

import 'cf_button.dart';

Future<bool?> showCfConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CfButton(
          label: cancelLabel,
          variant: CfButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        CfButton(
          label: confirmLabel,
          variant: danger ? CfButtonVariant.danger : CfButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}

Future<T?> showCfDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  List<Widget>? actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: child,
      actions: actions,
    ),
  );
}
