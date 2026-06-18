import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'wagon_wheel_field_geometry.dart';

/// Converts stored percentage coordinates ↔ pixel space with consistent scaling.
///
/// All wagon wheel screens must use the same [Size] derivation (via fixed
/// [WagonWheelFieldGeometry.fieldAspectRatio]) so a shot at (67.2, 24.1)
/// renders at the identical field position everywhere.
class WagonWheelCoordinateMapper {
  WagonWheelCoordinateMapper(this.size);

  final Size size;

  /// Square reference used when no widget size is available (tests).
  static Size get referenceSize => Size(
        WagonWheelFieldGeometry.referenceFieldExtent,
        WagonWheelFieldGeometry.referenceFieldExtent,
      );

  double get boundaryRadiusPixels =>
      size.shortestSide * WagonWheelFieldGeometry.boundaryRadiusFraction;

  Offset get groundCenterPixel => Offset(size.width / 2, size.height / 2);

  Offset get strikerWicketPixel => Offset(
        size.width * WagonWheelFieldGeometry.strikerWicketXPercent / 100,
        size.height * WagonWheelFieldGeometry.strikerWicketYPercent / 100,
      );

  Offset get bowlerWicketPixel => Offset(
        size.width * WagonWheelFieldGeometry.strikerWicketXPercent / 100,
        size.height * WagonWheelFieldGeometry.bowlerWicketYPercent / 100,
      );

  Offset percentToPixel(double x, double y) => Offset(
        size.width * x / 100,
        size.height * y / 100,
      );

  Offset pixelToPercent(Offset pixel) => Offset(
        (pixel.dx / size.width * 100)
            .clamp(WagonWheelFieldGeometry.groundEdgeMarginPercent, 100 - WagonWheelFieldGeometry.groundEdgeMarginPercent),
        (pixel.dy / size.height * 100)
            .clamp(WagonWheelFieldGeometry.groundEdgeMarginPercent, 100 - WagonWheelFieldGeometry.groundEdgeMarginPercent),
      );

  /// Full-canvas percentage (0–100) without edge margin — used for six storage.
  Offset pixelToPercentUnclamped(Offset pixel) => Offset(
        (pixel.dx / size.width * 100).clamp(0.0, 100.0),
        (pixel.dy / size.height * 100).clamp(0.0, 100.0),
      );

  /// Distance from ground centre in boundary units (1.0 = boundary rope).
  double boundaryDistance(double xPercent, double yPercent) {
    final p = percentToPixel(xPercent, yPercent);
    final dx = p.dx - groundCenterPixel.dx;
    final dy = p.dy - groundCenterPixel.dy;
    return math.sqrt(dx * dx + dy * dy) / boundaryRadiusPixels;
  }

  WagonWheelZone zoneAt(double xPercent, double yPercent) {
    final d = boundaryDistance(xPercent, yPercent);
    if (d < WagonWheelFieldGeometry.zoneAInnerMax) {
      return WagonWheelZone.insideField;
    }
    if (d <= WagonWheelFieldGeometry.zoneBMax) {
      return WagonWheelZone.boundaryRope;
    }
    return WagonWheelZone.outsideBoundary;
  }

  double angleFromStriker(double xPercent, double yPercent) {
    final p = percentToPixel(xPercent, yPercent);
    return angleFromStrikerPixel(p);
  }

  double angleFromStrikerPixel(Offset pixel) => math.atan2(
        pixel.dy - strikerWicketPixel.dy,
        pixel.dx - strikerWicketPixel.dx,
      );

  Offset percentAlongStrikerRay(double angle, double distancePixels) {
    final pixel = _pixelAlongStrikerRay(angle, distancePixels);
    return pixelToPercent(pixel);
  }

  Offset percentAlongStrikerRayUnclamped(double angle, double distancePixels) {
    final pixel = _pixelAlongStrikerRay(angle, distancePixels);
    return pixelToPercentUnclamped(pixel);
  }

  Offset _pixelAlongStrikerRay(double angle, double distancePixels) => Offset(
        strikerWicketPixel.dx + math.cos(angle) * distancePixels,
        strikerWicketPixel.dy + math.sin(angle) * distancePixels,
      );

  /// Largest distance along [angle] from striker that stays inside Zone A.
  double maxInsideDistancePixels(double angle) {
    return _searchAlongRay(
      angle,
      (x, y) => boundaryDistance(x, y) <= WagonWheelFieldGeometry.zoneAInnerMax,
      maxDistance: size.shortestSide * 1.2,
    );
  }

  double get minimumOutsideBeyondRopePixels =>
      boundaryRadiusPixels * WagonWheelFieldGeometry.sixMinimumOutsideFraction;

  /// Distance from striker along [angle] to the boundary rope (pixels).
  double boundaryExitDistancePixels(double angle) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    return _rayCircleExitDistance(
          origin: strikerWicketPixel,
          unitDir: dir,
          center: groundCenterPixel,
          radius: boundaryRadiusPixels,
        ) ??
        boundaryRadiusPixels * 0.75;
  }

  /// Nearest valid six point just outside the circular boundary along [angle].
  Offset nearestOutsideAlongAngle(double angle) {
    final alongRay =
        boundaryExitDistancePixels(angle) + minimumOutsideBeyondRopePixels;
    return percentAlongStrikerRayUnclamped(angle, alongRay);
  }

  /// Furthest distance along [angle] where the point stays within six max zone.
  double maxSixDistancePixels(double angle) {
    return _searchAlongRay(
      angle,
      (x, y) => boundaryDistance(x, y) <= WagonWheelFieldGeometry.zoneCMax,
      maxDistance: size.shortestSide * 1.5,
      unclamped: true,
    );
  }

  /// Distance along a ray from [origin] to where it exits the boundary circle.
  double? _rayCircleExitDistance({
    required Offset origin,
    required Offset unitDir,
    required Offset center,
    required double radius,
  }) {
    final f = origin - center;
    final b = 2 * (f.dx * unitDir.dx + f.dy * unitDir.dy);
    final c = f.dx * f.dx + f.dy * f.dy - radius * radius;
    final disc = b * b - 4 * c;
    if (disc < 0) return null;

    final s = math.sqrt(disc);
    final t1 = (-b - s) / 2;
    final t2 = (-b + s) / 2;

    if (t2 > 0) return t2;
    if (t1 > 0) return t1;
    return null;
  }

  double _searchAlongRay(
    double angle,
    bool Function(double x, double y) predicate, {
    required double maxDistance,
    bool unclamped = false,
  }) {
    var lo = 0.0;
    var hi = maxDistance;
    for (var i = 0; i < 48; i++) {
      final mid = (lo + hi) / 2;
      final p = unclamped
          ? percentAlongStrikerRayUnclamped(angle, mid)
          : percentAlongStrikerRay(angle, mid);
      if (predicate(p.dx, p.dy)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hi;
  }
}
