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

  static const int bowlerNameMaxLength = 20;

  static double totalScoreFontSize(double scale) => 28 * scale;

  static double oversFontSize(double scale) => 20 * scale;

  static double powerplayFontSize(double scale) => 12 * scale;

  static double playerNameFontSize(double scale) => 16 * scale;

  static double playerRunsFontSize(double scale) => 15 * scale;

  static double playerBallsFontSize(double scale) => 12 * scale;

  static double bowlerNameFontSize(double scale) => 16 * scale;

  static double bowlerFiguresFontSize(double scale) => 16 * scale;

  static double chipLabelFontSize(double scale) => 13 * scale;

  static double chipValueFontSize(double scale) => 16 * scale;

  static double ballCellFontSize(double scale, {bool compact = false}) =>
      (compact ? 9 : 11) * scale;

  static TextStyle playerNameStyle(
    ScorebugTokens tokens,
    double scale, {
    required bool onStrike,
  }) =>
      TextStyle(
        color: onStrike ? tokens.white : tokens.white.withValues(alpha: 0.88),
        fontSize: playerNameFontSize(scale),
        fontWeight: onStrike ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: 0.4,
        height: 1.1,
      );

  static TextStyle bowlerNameStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.white,
        fontSize: bowlerNameFontSize(scale),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        height: 1.1,
      );

  static TextStyle bowlerFiguresStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.white.withValues(alpha: 0.92),
        fontSize: bowlerFiguresFontSize(scale),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.1,
      );

  static TextStyle chipLabelStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.onScore,
        fontSize: chipLabelFontSize(scale),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      );

  static TextStyle chipValueStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.onScore,
        fontSize: chipValueFontSize(scale),
        fontWeight: FontWeight.w900,
      );
}
