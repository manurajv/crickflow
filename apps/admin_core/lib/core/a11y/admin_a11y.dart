import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../l10n/generated/admin_localizations.dart';

/// Accessibility helpers for CrickFlow Admin (WCAG-oriented).
///
/// Does not alter business logic — wrappers and announcements only.
abstract final class AdminA11y {
  /// Announce a short message to screen readers (polite).
  static void announce(BuildContext context, String message) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      direction,
    );
  }

  static AdminLocalizations? l10nOf(BuildContext context) {
    try {
      return AdminLocalizations.of(context);
    } catch (_) {
      return null;
    }
  }

  /// Visible focus ring matching design tokens (use on custom focusables).
  static BoxDecoration focusDecoration(Color focusRing, {double radius = 8}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: focusRing, width: 2),
    );
  }

  /// Wrap a data table region with an accessible label.
  static Widget labeledRegion({
    required String label,
    required Widget child,
    bool button = false,
  }) {
    return Semantics(
      container: true,
      label: label,
      button: button,
      child: child,
    );
  }

  /// Icon-only control with required tooltip + semantics label.
  static Widget iconAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

/// Extension for quick l10n access.
extension AdminL10nContext on BuildContext {
  AdminLocalizations get l10n => AdminLocalizations.of(this);

  AdminLocalizations? get l10nOrNull {
    try {
      return AdminLocalizations.of(this);
    } catch (_) {
      return null;
    }
  }
}
