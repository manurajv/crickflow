import 'package:flutter/material.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_colors.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_coordinate_mapper.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_field_geometry.dart';
/// Single shared renderer for ground, shots, and selection marker.
class WagonWheelRenderer {
  WagonWheelRenderer._();

  static void paintGround(Canvas canvas, Size size) {
    final mapper = WagonWheelCoordinateMapper(size);
    final rect = Offset.zero & size;
    final boundaryR = mapper.boundaryRadiusPixels;
    final center = mapper.groundCenterPixel;
    final groundRRect =
        RRect.fromRectAndRadius(rect, const Radius.circular(12));

    canvas.drawRRect(
      groundRRect,
      Paint()..color = WagonWheelFieldGeometry.outsideFieldColor,
    );

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

    canvas.drawCircle(
      center,
      boundaryR + 6,
      Paint()
        ..color = WagonWheelFieldGeometry.outsideFieldEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    canvas.drawCircle(
      center,
      boundaryR,
      Paint()
        ..color = WagonWheelFieldGeometry.boundaryRopeGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = WagonWheelFieldGeometry.boundaryRopeGlowWidth,
    );

    canvas.drawCircle(
      center,
      boundaryR,
      Paint()
        ..color = WagonWheelFieldGeometry.boundaryRopeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = WagonWheelFieldGeometry.boundaryRopeStrokeWidth,
    );

    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      center,
      size.shortestSide * WagonWheelFieldGeometry.innerCircleRadiusFraction,
      innerPaint,
    );

    final pitchRect = WagonWheelFieldGeometry.pitchRect(size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitchRect, const Radius.circular(2)),
      Paint()..color = WagonWheelFieldGeometry.pitchColor,
    );

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

    _paintWicket(canvas, mapper.strikerWicketPixel);
  }

  static void paintShots(
    Canvas canvas,
    Size size,
    List<WagonWheelShotPoint> shots, {
    int maxShots = 500,
  }) {
    final mapper = WagonWheelCoordinateMapper(size);
    final origin = mapper.strikerWicketPixel;
    final renderShots =
        shots.length > maxShots ? shots.sublist(shots.length - maxShots) : shots;

    final linePaint = Paint()
      ..strokeWidth = WagonWheelFieldGeometry.shotLineWidth
      ..strokeCap = StrokeCap.round;

    final endpointPaint = Paint();

    for (final shot in renderShots) {
      final end = mapper.percentToPixel(
        shot.wagonWheel.x,
        shot.wagonWheel.y,
      );
      final color = WagonWheelColors.forBatsmanRuns(shot.batsmanRuns);
      linePaint.color = color.withValues(
        alpha: WagonWheelFieldGeometry.shotLineOpacity,
      );
      endpointPaint.color = color.withValues(
        alpha: WagonWheelFieldGeometry.shotLineOpacity,
      );

      canvas.drawLine(origin, end, linePaint);
      canvas.drawCircle(
        end,
        WagonWheelFieldGeometry.shotEndpointRadius,
        endpointPaint,
      );
    }
  }

  static void paintSelectionPreview(
    Canvas canvas,
    Size size, {
    required double markerX,
    required double markerY,
    required Color accentColor,
  }) {
    final mapper = WagonWheelCoordinateMapper(size);
    final marker = mapper.percentToPixel(markerX, markerY);
    final origin = mapper.strikerWicketPixel;

    final previewPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = WagonWheelFieldGeometry.shotLineWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origin, marker, previewPaint);

    paintSelectionMarker(canvas, marker, accent: accentColor);
  }

  static void paintSelectionMarker(
    Canvas canvas,
    Offset position, {
    required Color accent,
  }) {
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
      Paint()..color = accent.withValues(alpha: 0.35),
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

  // ── Future modes (not exposed in UI) ─────────────────────────────────────

  @visibleForTesting
  static void paintScatterMode(
    Canvas canvas,
    Size size,
    List<WagonWheelShotPoint> shots,
  ) {
    paintShots(canvas, size, shots);
  }

  @visibleForTesting
  static void paintHeatmapMode(
    Canvas canvas,
    Size size,
    List<WagonWheelShotPoint> shots,
  ) {
    const grid = 12;
    final cellW = size.width / grid;
    final cellH = size.height / grid;
    final counts = List.generate(grid, (_) => List.filled(grid, 0));

    for (final shot in shots) {
      final col =
          (shot.wagonWheel.x / 100 * grid).floor().clamp(0, grid - 1);
      final row =
          (shot.wagonWheel.y / 100 * grid).floor().clamp(0, grid - 1);
      counts[row][col]++;
    }

    var maxCount = 1;
    for (final row in counts) {
      for (final c in row) {
        if (c > maxCount) maxCount = c;
      }
    }

    for (var r = 0; r < grid; r++) {
      for (var c = 0; c < grid; c++) {
        final n = counts[r][c];
        if (n == 0) continue;
        final t = n / maxCount;
        canvas.drawRect(
          Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFC107),
              const Color(0xFFE53935),
              t,
            )!
                .withValues(alpha: 0.15 + t * 0.55),
        );
      }
    }
  }
}

/// Shared canvas widget — fixed aspect ratio guarantees identical layout.
class WagonWheelFieldCanvas extends StatelessWidget {
  const WagonWheelFieldCanvas({
    super.key,
    this.shots = const [],
    this.markerX,
    this.markerY,
    this.accentColor,
    this.maxWidth,
  });

  final List<WagonWheelShotPoint> shots;
  final double? markerX;
  final double? markerY;
  final Color? accentColor;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = maxWidth ??
            (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : WagonWheelFieldGeometry.referenceFieldExtent);
        return SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: WagonWheelFieldGeometry.fieldAspectRatio,
            child: CustomPaint(
              painter: _WagonWheelCanvasPainter(
                shots: shots,
                markerX: markerX,
                markerY: markerY,
                accentColor: accentColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WagonWheelCanvasPainter extends CustomPainter {
  _WagonWheelCanvasPainter({
    required this.shots,
    this.markerX,
    this.markerY,
    this.accentColor,
  });

  final List<WagonWheelShotPoint> shots;
  final double? markerX;
  final double? markerY;
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    WagonWheelRenderer.paintGround(canvas, size);
    if (shots.isNotEmpty) {
      WagonWheelRenderer.paintShots(canvas, size, shots);
    }
    if (markerX != null && markerY != null && accentColor != null) {
      WagonWheelRenderer.paintSelectionPreview(
        canvas,
        size,
        markerX: markerX!,
        markerY: markerY!,
        accentColor: accentColor!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WagonWheelCanvasPainter oldDelegate) {
    return oldDelegate.shots != shots ||
        oldDelegate.markerX != markerX ||
        oldDelegate.markerY != markerY ||
        oldDelegate.accentColor != accentColor;
  }
}
