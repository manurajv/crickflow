import 'package:flutter/material.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_field_geometry.dart';

/// Shared ground rendering — field zones, pitch, boundary rope, wicket.
class WagonWheelGroundRenderer {
  WagonWheelGroundRenderer._();

  static void paintGround(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final boundaryR = WagonWheelFieldGeometry.boundaryRadiusPixels(size);
    final groundRRect =
        RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Outside ground — dark non-playing area (full canvas).
    canvas.drawRRect(
      groundRRect,
      Paint()..color = WagonWheelFieldGeometry.outsideFieldColor,
    );

    // Inside playing field — green oval clipped to boundary circle.
    canvas.save();
    canvas.clipRRect(groundRRect);
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: boundaryR)),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WagonWheelFieldGeometry.insideFieldTop,
            WagonWheelFieldGeometry.insideFieldBottom,
          ],
        ).createShader(rect),
    );
    canvas.restore();

    // Subtle ring outside boundary for depth.
    canvas.drawCircle(
      center,
      boundaryR + 6,
      Paint()
        ..color = WagonWheelFieldGeometry.outsideFieldEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Boundary rope glow.
    canvas.drawCircle(
      center,
      boundaryR,
      Paint()
        ..color = WagonWheelFieldGeometry.boundaryRopeGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = WagonWheelFieldGeometry.boundaryRopeGlowWidth,
    );

    // Boundary rope line.
    canvas.drawCircle(
      center,
      boundaryR,
      Paint()
        ..color = WagonWheelFieldGeometry.boundaryRopeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = WagonWheelFieldGeometry.boundaryRopeStrokeWidth,
    );

    // Inner field circles (30-yard reference).
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      center,
      size.shortestSide * WagonWheelFieldGeometry.innerCircleRadiusFraction,
      innerPaint,
    );

    // Pitch strip.
    final pitchRect = WagonWheelFieldGeometry.pitchRect(size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitchRect, const Radius.circular(2)),
      Paint()..color = WagonWheelFieldGeometry.pitchColor,
    );

    // Crease lines.
    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.2;
    final pitchH = pitchRect.height;
    final creaseY1 = pitchRect.top + pitchH * 0.14;
    final creaseY2 = pitchRect.bottom - pitchH * 0.14;
    canvas.drawLine(
      Offset(pitchRect.left, creaseY1),
      Offset(pitchRect.right, creaseY1),
      creasePaint,
    );
    canvas.drawLine(
      Offset(pitchRect.left, creaseY2),
      Offset(pitchRect.right, creaseY2),
      creasePaint,
    );

    // Striker wicket (line origin).
    _paintWicket(canvas, WagonWheelFieldGeometry.strikerWicketOffset(size));
  }

  static void _paintWicket(Canvas canvas, Offset position) {
    canvas.drawCircle(
      position,
      5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      position,
      3.5,
      Paint()..color = WagonWheelFieldGeometry.wicketColor,
    );
    canvas.drawCircle(
      position,
      5,
      Paint()
        ..color = WagonWheelFieldGeometry.wicketColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  static void paintSelectionMarker(
    Canvas canvas,
    Offset position, {
    required Color accent,
  }) {
    // Soft shadow for contrast on green/outside areas.
    canvas.drawCircle(
      position + const Offset(1, 2),
      WagonWheelFieldGeometry.selectionMarkerRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawCircle(
      position,
      WagonWheelFieldGeometry.selectionMarkerRadius,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      position,
      WagonWheelFieldGeometry.selectionMarkerRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      position,
      WagonWheelFieldGeometry.selectionMarkerCoreRadius,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      position,
      WagonWheelFieldGeometry.selectionMarkerCoreRadius * 0.45,
      Paint()..color = Colors.white,
    );
  }
}
