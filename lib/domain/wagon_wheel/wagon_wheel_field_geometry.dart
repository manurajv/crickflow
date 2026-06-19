import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'wagon_wheel_coordinate_mapper.dart';

/// Broadcast-style field zones for shot validation.
enum WagonWheelZone {
  insideField,
  boundaryRope,
  outsideBoundary,
}

/// Centralized cricket ground geometry — single source of truth for every screen.
class WagonWheelFieldGeometry {
  WagonWheelFieldGeometry._();

  // ── Fixed aspect ratio (prevents drift between Insights / Full View) ─────

  static const double fieldAspectRatio = 1.0;
  static const double referenceFieldExtent = 300.0;

  // ── Percentage anchors ───────────────────────────────────────────────────

  static const double groundCenterXPercent = 50.0;
  static const double groundCenterYPercent = 50.0;
  static const double strikerWicketXPercent = 50.0;

  // ── Pitch proportions ────────────────────────────────────────────────────

  static const double pitchWidthFraction = 0.08;
  static const double pitchLengthFraction = 0.28;
  static const double creaseInsetFraction = 0.14;

  /// Striker end — top wicket on the pitch (bowler end is bottom).
  static double get strikerWicketYPercent =>
      groundCenterYPercent -
      pitchLengthFraction * 50 +
      pitchLengthFraction * 100 * creaseInsetFraction;

  static double get bowlerWicketYPercent =>
      groundCenterYPercent +
      pitchLengthFraction * 50 -
      pitchLengthFraction * 100 * creaseInsetFraction;

  // ── Boundary zones (normalized: 1.0 = boundary rope radius) ──────────────

  /// Zone A — strictly inside field (not on rope).
  static const double zoneAInnerMax = 0.868;

  /// Zone B — outer edge of boundary rope.
  static const double zoneBMax = 1.0;

  /// Zone C — max selectable distance for 4s and 6s beyond rope.
  static const double zoneCMax = 1.24;

  /// Minimum push past the rope when a six tap lands inside the field.
  static const double sixMinimumOutsideFraction = 0.008;

  static const double groundEdgeMarginPercent = 2.0;

  // ── Render fractions ─────────────────────────────────────────────────────

  static const double boundaryRadiusFraction = 0.38;
  static const double innerCircleRadiusFraction = 0.22;
  static const double boundaryRopeStrokeWidth = 3.0;
  static const double boundaryRopeGlowWidth = 5.5;

  // ── Uniform shot styling (colour only varies) ──────────────────────────

  static const double shotLineWidth = 2.0;
  static const double shotLineOpacity = 0.82;
  static const double shotEndpointRadius = 4.0;

  static const double selectionMarkerRadius = 12.0;
  static const double selectionMarkerCoreRadius = 6.0;

  // ── Theme palettes (use [forTheme] in renderer) ───────────────────────────

  static WagonWheelFieldPalette forTheme(bool isLight) =>
      isLight ? WagonWheelFieldPalette.light : WagonWheelFieldPalette.dark;

  // Legacy dark tokens — prefer [WagonWheelFieldPalette.dark].
  static const Color insideFieldTop = Color(0xFF2E7D32);
  static const Color insideFieldBottom = Color(0xFF1B5E20);
  static const Color outsideFieldColor = Color(0xFF3A3A3A);
  static const Color outsideFieldEdge = Color(0xFF2C2C2C);
  static const Color boundaryRopeColor = Color(0xFFF5F5F5);
  static const Color boundaryRopeGlow = Color(0x40FFFFFF);
  static const Color pitchColor = Color(0xFF8D6E63);
  static const Color wicketColor = Color(0xFFECEFF1);

  // ── Validation ─────────────────────────────────────────────────────────────

  static bool isZoneAllowed(WagonWheelZone zone, int batsmanRuns) {
    return switch (batsmanRuns) {
      1 || 2 || 3 || 5 => zone == WagonWheelZone.insideField,
      4 => true,
      6 => zone == WagonWheelZone.outsideBoundary,
      _ => zone == WagonWheelZone.insideField,
    };
  }

  /// Clamps to the nearest valid point for [batsmanRuns] using pixel-accurate
  /// circular boundary distance and striker-wicket ray snapping.
  ///
  /// Sixes accept any point outside the boundary rope; inside taps are pushed
  /// to the nearest valid point along the same angle.
  static Offset clampCoordinate(
    double x,
    double y,
    int batsmanRuns, [
    Size? fieldSize,
  ]) {
    final size = fieldSize ?? WagonWheelCoordinateMapper.referenceSize;
    final mapper = WagonWheelCoordinateMapper(size);

    if (batsmanRuns == 6) {
      x = x.clamp(0.0, 100.0);
      y = y.clamp(0.0, 100.0);
      final angle = mapper.angleFromStriker(x, y);
      final zone = mapper.zoneAt(x, y);
      if (zone == WagonWheelZone.outsideBoundary &&
          _withinMaxDistance(mapper, x, y, batsmanRuns)) {
        return Offset(x, y);
      }
      return _clampSix(mapper, x, y, angle);
    }

    x = x.clamp(groundEdgeMarginPercent, 100 - groundEdgeMarginPercent);
    y = y.clamp(groundEdgeMarginPercent, 100 - groundEdgeMarginPercent);

    final angle = mapper.angleFromStriker(x, y);

    final zone = mapper.zoneAt(x, y);
    if (isZoneAllowed(zone, batsmanRuns) &&
        _withinMaxDistance(mapper, x, y, batsmanRuns)) {
      return Offset(x, y);
    }

    return switch (batsmanRuns) {
      1 || 2 || 3 || 5 => mapper.percentAlongStrikerRay(
          angle,
          mapper.maxInsideDistancePixels(angle) * 0.98,
        ),
      4 => _clampFour(mapper, x, y, angle),
      _ => mapper.percentAlongStrikerRay(
          angle,
          mapper.maxInsideDistancePixels(angle) * 0.98,
        ),
    };
  }

  static bool _withinMaxDistance(
    WagonWheelCoordinateMapper mapper,
    double x,
    double y,
    int batsmanRuns,
  ) {
    final d = mapper.boundaryDistance(x, y);
    return switch (batsmanRuns) {
      1 || 2 || 3 || 5 => d < zoneAInnerMax,
      4 => d <= zoneCMax,
      6 => d > zoneBMax && d <= zoneCMax,
      _ => d < zoneAInnerMax,
    };
  }

  static Offset _clampSix(
    WagonWheelCoordinateMapper mapper,
    double x,
    double y,
    double angle,
  ) {
    final d = mapper.boundaryDistance(x, y);
    if (d > zoneCMax) {
      return mapper.percentAlongStrikerRayUnclamped(
        angle,
        mapper.maxSixDistancePixels(angle),
      );
    }
    return mapper.nearestOutsideAlongAngle(angle);
  }

  static Offset _clampFour(
    WagonWheelCoordinateMapper mapper,
    double x,
    double y,
    double angle,
  ) {
    final d = mapper.boundaryDistance(x, y);
    if (d <= zoneCMax) return Offset(x, y);
    return mapper.percentAlongStrikerRay(
      angle,
      mapper.boundaryExitDistancePixels(angle),
    );
  }

  static WagonWheelZone zoneAt(double x, double y, [Size? fieldSize]) {
    final mapper = WagonWheelCoordinateMapper(
      fieldSize ?? WagonWheelCoordinateMapper.referenceSize,
    );
    return mapper.zoneAt(x, y);
  }

  static double boundaryDistance(double x, double y, [Size? fieldSize]) {
    final mapper = WagonWheelCoordinateMapper(
      fieldSize ?? WagonWheelCoordinateMapper.referenceSize,
    );
    return mapper.boundaryDistance(x, y);
  }

  // ── Render helpers ───────────────────────────────────────────────────────

  static Size fieldSizeFromWidth(double width) => Size(
        width,
        width / fieldAspectRatio,
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
        4 => 'Fours can land on or beyond the boundary rope.',
        6 => 'Mark where the six landed — beyond the boundary rope.',
        _ => 'Tap or drag to mark where the ball landed.',
      };

  /// Default scorer marker — down-left toward mid-off (striker at top, RHB view).
  static Offset defaultMidOffMarker(int batsmanRuns, [Size? fieldSize]) {
    final size = fieldSize ?? WagonWheelCoordinateMapper.referenceSize;
    final mapper = WagonWheelCoordinateMapper(size);
    const angle = math.pi * 0.72;
    final distance = mapper.maxInsideDistancePixels(angle) * 0.58;
    final raw = mapper.percentAlongStrikerRay(angle, distance);
    return clampCoordinate(raw.dx, raw.dy, batsmanRuns, size);
  }
}

/// Field colours for wagon wheel rendering — light vs dark chrome.
class WagonWheelFieldPalette {
  const WagonWheelFieldPalette({
    required this.insideFieldTop,
    required this.insideFieldBottom,
    required this.outsideFieldColor,
    required this.outsideFieldEdge,
    required this.boundaryRopeColor,
    required this.boundaryRopeGlow,
    required this.pitchColor,
    required this.wicketColor,
    required this.sideLabelColor,
    required this.innerCircleColor,
    required this.creaseColor,
    required this.markerShadowColor,
  });

  final Color insideFieldTop;
  final Color insideFieldBottom;
  final Color outsideFieldColor;
  final Color outsideFieldEdge;
  final Color boundaryRopeColor;
  final Color boundaryRopeGlow;
  final Color pitchColor;
  final Color wicketColor;
  final Color sideLabelColor;
  final Color innerCircleColor;
  final Color creaseColor;
  final Color markerShadowColor;

  static const dark = WagonWheelFieldPalette(
    insideFieldTop: Color(0xFF2E7D32),
    insideFieldBottom: Color(0xFF1B5E20),
    outsideFieldColor: Color(0xFF3A3A3A),
    outsideFieldEdge: Color(0xFF2C2C2C),
    boundaryRopeColor: Color(0xFFF5F5F5),
    boundaryRopeGlow: Color(0x40FFFFFF),
    pitchColor: Color(0xFF8D6E63),
    wicketColor: Color(0xFFECEFF1),
    sideLabelColor: Color(0xB8FFFFFF),
    innerCircleColor: Color(0x12FFFFFF),
    creaseColor: Color(0x99FFFFFF),
    markerShadowColor: Color(0x73000000),
  );

  static const light = WagonWheelFieldPalette(
    insideFieldTop: Color(0xFF4CAF50),
    insideFieldBottom: Color(0xFF2E7D32),
    outsideFieldColor: Color(0xFFE8EAED),
    outsideFieldEdge: Color(0xFFD0D5DD),
    boundaryRopeColor: Color(0xFFFFFFFF),
    boundaryRopeGlow: Color(0x4DFFFFFF),
    pitchColor: Color(0xFF9D7B6B),
    wicketColor: Color(0xFF424242),
    sideLabelColor: Color(0xF0FFFFFF),
    innerCircleColor: Color(0x1FFFFFFF),
    creaseColor: Color(0xCCFFFFFF),
    markerShadowColor: Color(0x33000000),
  );
}
