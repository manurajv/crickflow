import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';

/// Responsive scale and sizing for portrait (9:16) broadcast scorebugs.
class PortraitScorebugLayout {
  PortraitScorebugLayout._();

  static double scaleForWidth(double width) => (width / 360).clamp(0.85, 1.25);

  static double barHeight(double scale) => 46 * scale;

  static double secondaryRowHeight(double scale) => 24 * scale;

  static EdgeInsets topHeaderPadding(double scale) =>
      EdgeInsets.fromLTRB(12 * scale, 18 * scale, 12 * scale, 0);

  /// Space reserved below [PortraitTopHeader] (title + logo + LIVE badge).
  static double topHeaderReservedHeight(double scale) =>
      (18 + 34 + 4 + 14 + 16) * scale;

  static BoxShadow barShadow() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.4),
        blurRadius: 14,
        offset: const Offset(0, -3),
      );

  static TextStyle headerTitleStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.white,
        fontSize: 13 * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.15,
      );
}
