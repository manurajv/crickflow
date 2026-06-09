import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Broadcast-style field zones for shot validation.
enum WagonWheelZone {
  /// Zone A — inside the boundary rope.
  insideField,

  /// Zone B — on the boundary rope band.
  boundaryRope,

  /// Zone C — outside the boundary.
  outsideBoundary,
}

/// Centralized cricket ground geometry (percentage + render fractions).
///
/// All wagon wheel painters and validators read from here so future stadium
/// templates / custom ground images can swap dimensions without touching analytics.
class WagonWheelFieldGeometry {
  WagonWheelFieldGeometry._();

  // ── Percentage coordinate anchors (storage space 0–100) ──────────────────

  static const double groundCenterXPercent = 50.0;
  static const double groundCenterYPercent = 50.0;

  /// Striker's wicket — line origin for all shot rendering.
  static const double strikerWicketXPercent = 50.0;

  // ── Pitch proportions (render fractions of ground size) ──────────────────

  /// Pitch width as fraction of ground width (~8%).
  static const double pitchWidthFraction = 0.08;

  /// Pitch length — reduced ~33% from original 0.42 for broadcast proportions.
  static const double pitchLengthFraction = 0.28;

  /// Striker crease sits near the batsman end (larger Y in top-down view).
  static const double strikerCreasePitchFraction = 0.44;

  static double get strikerWicketYPercent =>
      groundCenterYPercent +
      pitchLengthFraction * 50 * strikerCreasePitchFraction;

  // ── Boundary circle (distance from ground centre in %-units) ─────────────

  /// Inner edge of boundary rope — Zone A ends here.
  static const double boundaryInnerRadiusPercent = 33.0;

  /// Outer edge of boundary rope — Zone B ends here.
  static const double boundaryOuterRadiusPercent = 37.0;

  /// Max selectable radius for sixes (Zone C).
  static const double outsideMaxRadiusPercent = 47.0;

  /// Minimum margin from ground edge when clamping.
  static const double groundEdgeMarginPercent = 2.0;

  // ── Render fractions (pixel space) ───────────────────────────────────────

  static const double boundaryRadiusFraction = 0.38;
  static const double innerCircleRadiusFraction = 0.22;
  static const double boundaryRopeStrokeWidth = 3.0;
  static const double boundaryRopeGlowWidth = 5.5;

  // ── Colours ──────────────────────────────────────────────────────────────

  static const Color insideFieldTop = Color(0xFF2E7D32);
  static const Color insideFieldBottom = Color(0xFF1B5E20);
  static const Color outsideFieldColor = Color(0xFF3A3A3A);
  static const Color outsideFieldEdge = Color(0xFF2C2C2C);
  static const Color boundaryRopeColor = Color(0xFFF5F5F5);
  static const Color boundaryRopeGlow = Color(0x40FFFFFF);
  static const Color pitchColor = Color(0xFF8D6E63);
  static const Color wicketColor = Color(0xFFECEFF1);

  // ── Shot line / marker styling ───────────────────────────────────────────

  static const double sixLineWidth = 3.2;
  static const double sixLineOpacity = 0.95;
  static const double fourLineWidth = 2.4;
  static const double defaultLineWidth = 1.5;
  static const double defaultLineOpacity = 0.75;
  static const double selectionMarkerRadius = 12.0;
  static const double selectionMarkerCoreRadius = 6.0;

  // ── Coordinate math ──────────────────────────────────────────────────────

  static double distanceFromCenter(double x, double y) {
    final dx = x - groundCenterXPercent;
    final dy = y - groundCenterYPercent;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double angleFromCenter(double x, double y) {
    return math.atan2(
      y - groundCenterYPercent,
      x - groundCenterXPercent,
    );
  }

  static WagonWheelZone zoneAt(double x, double y) {
    final d = distanceFromCenter(x, y);
    if (d < boundaryInnerRadiusPercent) return WagonWheelZone.insideField;
    if (d <= boundaryOuterRadiusPercent) return WagonWheelZone.boundaryRope;
    return WagonWheelZone.outsideBoundary;
  }

  static bool isZoneAllowed(WagonWheelZone zone, int batsmanRuns) {
    return switch (batsmanRuns) {
      1 || 2 || 3 || 5 => zone == WagonWheelZone.insideField,
      4 => zone == WagonWheelZone.insideField ||
          zone == WagonWheelZone.boundaryRope,
      6 => true,
      _ => zone == WagonWheelZone.insideField,
    };
  }

  static double maxRadiusPercentForRuns(int batsmanRuns) {
    return switch (batsmanRuns) {
      1 || 2 || 3 || 5 => boundaryInnerRadiusPercent - 0.8,
      4 => boundaryOuterRadiusPercent,
      6 => outsideMaxRadiusPercent,
      _ => boundaryInnerRadiusPercent - 0.8,
    };
  }

  /// Clamps a tap/drag to the nearest valid point for [batsmanRuns].
  static Offset clampCoordinate(double x, double y, int batsmanRuns) {
    x = x.clamp(groundEdgeMarginPercent, 100 - groundEdgeMarginPercent);
    y = y.clamp(groundEdgeMarginPercent, 100 - groundEdgeMarginPercent);

    final maxR = maxRadiusPercentForRuns(batsmanRuns);
    final dist = distanceFromCenter(x, y);
    final angle = angleFromCenter(x, y);
    final zone = zoneAt(x, y);

    if (dist <= maxR && isZoneAllowed(zone, batsmanRuns)) {
      return Offset(x, y);
    }

    final targetR = dist > maxR ? maxR : _nearestAllowedRadius(zone, batsmanRuns);
    return _pointOnRadius(angle, targetR);
  }

  static double _nearestAllowedRadius(WagonWheelZone zone, int batsmanRuns) {
    return switch (batsmanRuns) {
      4 when zone == WagonWheelZone.outsideBoundary =>
        boundaryOuterRadiusPercent,
      6 => boundaryOuterRadiusPercent + 3,
      _ => boundaryInnerRadiusPercent - 0.8,
    };
  }

  static Offset _pointOnRadius(double angle, double radius) {
    return Offset(
      (groundCenterXPercent + radius * math.cos(angle))
          .clamp(groundEdgeMarginPercent, 100 - groundEdgeMarginPercent),
      (groundCenterYPercent + radius * math.sin(angle))
          .clamp(groundEdgeMarginPercent, 100 - groundEdgeMarginPercent),
    );
  }

  // ── Render helpers (pixel space) ─────────────────────────────────────────

  static Offset strikerWicketOffset(Size size) => Offset(
        size.width * strikerWicketXPercent / 100,
        size.height * strikerWicketYPercent / 100,
      );

  static Offset percentToOffset(Size size, double x, double y) => Offset(
        size.width * x / 100,
        size.height * y / 100,
      );

  static Rect pitchRect(Size size) {
    final pitchW = size.width * pitchWidthFraction;
    final pitchH = size.height * pitchLengthFraction;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: pitchW,
      height: pitchH,
    );
  }

  static double boundaryRadiusPixels(Size size) =>
      size.shortestSide * boundaryRadiusFraction;

  static String hintForRuns(int runs) => switch (runs) {
        1 || 2 || 3 =>
          'Singles, doubles and triples must finish inside the boundary.',
        4 => 'Tap on the field or along the boundary rope.',
        6 => 'Sixes can be marked beyond the boundary rope.',
        _ => 'Tap or drag to mark where the ball landed.',
      };
}
