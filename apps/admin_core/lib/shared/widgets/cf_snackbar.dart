import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';

enum CfSnackKind { success, warning, error, info, progress }

/// Standardized floating snackbars for the admin design system.
abstract final class CfSnack {
  static void show(
    BuildContext context, {
    required String message,
    CfSnackKind kind = CfSnackKind.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colors = context.adminColors;
    final Color bg;
    final IconData icon;
    switch (kind) {
      case CfSnackKind.success:
        bg = colors.success;
        icon = Icons.check_circle_outline;
      case CfSnackKind.warning:
        bg = colors.warning;
        icon = Icons.warning_amber_outlined;
      case CfSnackKind.error:
        bg = colors.error;
        icon = Icons.error_outline;
      case CfSnackKind.progress:
        bg = colors.info;
        icon = Icons.hourglass_top_outlined;
      case CfSnackKind.info:
        bg = colors.textPrimary;
        icon = Icons.info_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: bg,
        content: Row(
          children: [
            if (kind == CfSnackKind.progress)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, kind: CfSnackKind.success);

  static void warning(BuildContext context, String message) =>
      show(context, message: message, kind: CfSnackKind.warning);

  static void error(BuildContext context, String message) =>
      show(context, message: message, kind: CfSnackKind.error);

  static void info(BuildContext context, String message) =>
      show(context, message: message, kind: CfSnackKind.info);
}
