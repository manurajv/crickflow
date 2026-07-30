import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import 'cf_button.dart';
import 'cf_empty_state.dart';

enum CfDialogKind {
  confirm,
  delete,
  archive,
  restore,
  warning,
  information,
  success,
  error,
}

Future<bool?> showCfConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
  CfDialogKind kind = CfDialogKind.confirm,
}) {
  final resolvedDanger = danger ||
      kind == CfDialogKind.delete ||
      kind == CfDialogKind.error;
  final icon = switch (kind) {
    CfDialogKind.delete => Icons.delete_outline,
    CfDialogKind.archive => Icons.archive_outlined,
    CfDialogKind.restore => Icons.restore_outlined,
    CfDialogKind.warning => Icons.warning_amber_outlined,
    CfDialogKind.information => Icons.info_outline,
    CfDialogKind.success => Icons.check_circle_outline,
    CfDialogKind.error => Icons.error_outline,
    CfDialogKind.confirm => Icons.help_outline,
  };

  return showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.adminColors;
      final accent = resolvedDanger
          ? colors.error
          : kind == CfDialogKind.success
              ? colors.success
              : kind == CfDialogKind.warning
                  ? colors.warning
                  : colors.info;
      return AlertDialog(
        icon: Icon(icon, color: accent, size: 28),
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
            variant: resolvedDanger
                ? CfButtonVariant.danger
                : kind == CfDialogKind.success
                    ? CfButtonVariant.success
                    : CfButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
}

Future<T?> showCfDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: child,
      actions: actions,
    ),
  );
}

/// Professional full-page error / permission / not-found state.
class CfErrorState extends StatelessWidget {
  const CfErrorState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  factory CfErrorState.network({VoidCallback? onRetry}) => CfErrorState(
        icon: Icons.wifi_off_outlined,
        title: 'Network error',
        message: 'Check your connection and try again.',
        onRetry: onRetry,
      );

  factory CfErrorState.permission() => const CfErrorState(
        icon: Icons.lock_outline,
        title: 'Permission required',
        message: 'You do not have access to this section.',
      );

  factory CfErrorState.notFound() => const CfErrorState(
        icon: Icons.search_off_outlined,
        title: 'Not found',
        message: 'This page or resource could not be found.',
      );

  @override
  Widget build(BuildContext context) {
    return CfEmptyState(
      icon: icon,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : CfButton(
              label: retryLabel,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
    );
  }
}
