import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';

/// Responsive scale and safe margins for landscape broadcast overlays.
class LandscapeScorebugLayout {
  LandscapeScorebugLayout._();

  static double scaleForWidth(double width) => (width / 1280).clamp(0.72, 1.4);

  static EdgeInsets safePadding(double scale) => EdgeInsets.fromLTRB(
        24 * scale,
        10 * scale,
        24 * scale,
        12 * scale,
      );

  /// Main scorebug bar height — TV reference uses a taller strip.
  static double barHeight(double scale) => 46 * scale;

  /// Secondary row (partnership / this over) above the main bar.
  static double secondaryRowHeight(double scale) => 24 * scale;

  static EdgeInsets topHeaderPadding(double scale) => EdgeInsets.only(
        left: 40 * scale,
        top: 16 * scale,
        right: 18 * scale,
      );

  /// Space reserved below [LandscapeTopHeader] (logo + LIVE badge).
  static double topHeaderReservedHeight(double scale) =>
      (16 + 50 + 30 + 16 + 14) * scale;

  /// Horizontal inset for scorebug and side intro panels (matches header).
  static double overlayHorizontalInset(double scale) => 40 * scale;

  /// Bottom inset so side panels sit above the scorebug bar.
  static double scorebugReservedHeight(double scale) =>
      secondaryRowHeight(scale) + (2 * scale) + barHeight(scale) + 36 * scale;

  static double panelGap(double scale) => 0 * scale;

  /// Horizontal inset for batting logo (left) and bowler column (right).
  static double edgeInset(double scale) => 8 * scale;

  /// Visible gap between the batsmen block and the bowler column — team logo width.
  static double batsmenBowlerGap(double scale) => barHeight(scale);

  static double batterGap(double scale) => 56 * scale;

  /// Total score (e.g. 20/1) and chase target chip typography.
  static double totalScoreFontSize(double scale) => 24 * scale;

  /// Secondary-row width aligned with the batting + batsmen bar (excludes bowler column).
  static double bannerWidthThroughBatsmen({
    required double totalWidth,
    required double scale,
  }) {
    final inset = edgeInset(scale);
    final gap = batsmenBowlerGap(scale);
    final bowlerColumnWidth =
        (totalWidth * 0.56).clamp(148 * scale, 230 * scale);
    return totalWidth - (2 * inset) - gap - bowlerColumnWidth;
  }

  static BoxShadow barShadow() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 12,
        offset: const Offset(0, -2),
      );

  static TextStyle labelStyle(ScorebugTokens tokens, double scale) => TextStyle(
        color: tokens.onScore,
        fontSize: 12 * scale,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      );

  static TextStyle valueStyle(ScorebugTokens tokens, double scale) => TextStyle(
        color: tokens.onScore,
        fontSize: 14 * scale,
        fontWeight: FontWeight.w900,
      );

  static TextStyle playerNameStyle(
    ScorebugTokens tokens,
    double scale, {
    required bool onStrike,
  }) =>
      TextStyle(
        color: onStrike ? tokens.white : tokens.white.withValues(alpha: 0.88),
        fontSize: (onStrike ? 18 : 16) * scale,
        fontWeight: onStrike ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.1,
      );

  static TextStyle playerRunsStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.white,
        fontSize: 18 * scale,
        fontWeight: FontWeight.w900,
        height: 1.1,
      );

  static TextStyle playerBallsStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.white.withValues(alpha: 0.65),
        fontSize: 14 * scale,
        fontWeight: FontWeight.w500,
        height: 1.1,
      );

  static TextStyle bowlerNameStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.white,
        fontSize: 16 * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        height: 1.1,
      );

  static TextStyle bowlerFiguresStyle(ScorebugTokens tokens, double scale) =>
      TextStyle(
        color: tokens.white.withValues(alpha: 0.92),
        fontSize: 16 * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.1,
      );
}
