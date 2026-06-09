import 'package:flutter/material.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_colors.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_field_geometry.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import 'wagon_wheel_ground_renderer.dart';

/// Draws a top-down cricket ground with shot lines from the striker's wicket.
class WagonWheelGroundPainter extends CustomPainter {
  WagonWheelGroundPainter({
    required this.shots,
    this.viewMode = WagonWheelViewMode.lines,
    this.showWicketOrigin = true,
    this.maxShotsToRender = 500,
  });

  final List<WagonWheelShotPoint> shots;
  final WagonWheelViewMode viewMode;
  final bool showWicketOrigin;
  final int maxShotsToRender;

  @override
  void paint(Canvas canvas, Size size) {
    WagonWheelGroundRenderer.paintGround(canvas, size);

    final origin = WagonWheelFieldGeometry.strikerWicketOffset(size);

    final renderShots = shots.length > maxShotsToRender
        ? shots.sublist(shots.length - maxShotsToRender)
        : shots;

    switch (viewMode) {
      case WagonWheelViewMode.heatmap:
        _paintHeatmap(canvas, size, renderShots);
        break;
      case WagonWheelViewMode.scatter:
        _paintScatter(canvas, size, origin, renderShots);
        break;
      case WagonWheelViewMode.lines:
        _paintLines(canvas, size, origin, renderShots);
        break;
    }
  }

  void _paintLines(
    Canvas canvas,
    Size size,
    Offset origin,
    List<WagonWheelShotPoint> renderShots,
  ) {
    for (final shot in renderShots) {
      final end = WagonWheelFieldGeometry.percentToOffset(
        size,
        shot.wagonWheel.x,
        shot.wagonWheel.y,
      );
      final color = WagonWheelColors.forBatsmanRuns(shot.batsmanRuns);
      final isSix = shot.batsmanRuns == 6;
      final linePaint = Paint()
        ..color = color.withValues(
          alpha: isSix
              ? WagonWheelFieldGeometry.sixLineOpacity
              : WagonWheelFieldGeometry.defaultLineOpacity,
        )
        ..strokeWidth = isSix
            ? WagonWheelFieldGeometry.sixLineWidth
            : shot.batsmanRuns >= 4
                ? WagonWheelFieldGeometry.fourLineWidth
                : WagonWheelFieldGeometry.defaultLineWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(origin, end, linePaint);
      canvas.drawCircle(
        end,
        isSix ? 5 : 3.5,
        Paint()..color = color,
      );
    }
  }

  void _paintScatter(
    Canvas canvas,
    Size size,
    Offset origin,
    List<WagonWheelShotPoint> renderShots,
  ) {
    for (final shot in renderShots) {
      final end = WagonWheelFieldGeometry.percentToOffset(
        size,
        shot.wagonWheel.x,
        shot.wagonWheel.y,
      );
      final color = WagonWheelColors.forBatsmanRuns(shot.batsmanRuns);
      final isSix = shot.batsmanRuns == 6;
      if (showWicketOrigin) {
        final linePaint = Paint()
          ..color = color.withValues(alpha: isSix ? 0.35 : 0.2)
          ..strokeWidth = isSix ? 2 : 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(origin, end, linePaint);
      }
      canvas.drawCircle(
        end,
        isSix ? 6 : shot.batsmanRuns >= 4 ? 5 : 3.5,
        Paint()
          ..color = color.withValues(alpha: isSix ? 0.95 : 0.85),
      );
    }
  }

  void _paintHeatmap(
    Canvas canvas,
    Size size,
    List<WagonWheelShotPoint> renderShots,
  ) {
    const grid = 12;
    final cellW = size.width / grid;
    final cellH = size.height / grid;
    final counts = List.generate(grid, (_) => List.filled(grid, 0));

    for (final shot in renderShots) {
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
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        canvas.drawRect(
          rect,
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

  @override
  bool shouldRepaint(covariant WagonWheelGroundPainter oldDelegate) {
    return oldDelegate.shots != shots ||
        oldDelegate.viewMode != viewMode ||
        oldDelegate.maxShotsToRender != maxShotsToRender;
  }
}

/// Interactive ground for shot selection during live scoring.
class WagonWheelSelectionPainter extends CustomPainter {
  WagonWheelSelectionPainter({
    required this.markerX,
    required this.markerY,
    required this.accentColor,
  });

  final double markerX;
  final double markerY;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    WagonWheelGroundRenderer.paintGround(canvas, size);

    final marker = WagonWheelFieldGeometry.percentToOffset(
      size,
      markerX,
      markerY,
    );
    final origin = WagonWheelFieldGeometry.strikerWicketOffset(size);

    final previewPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origin, marker, previewPaint);

    WagonWheelGroundRenderer.paintSelectionMarker(
      canvas,
      marker,
      accent: accentColor,
    );
  }

  @override
  bool shouldRepaint(covariant WagonWheelSelectionPainter oldDelegate) {
    return oldDelegate.markerX != markerX ||
        oldDelegate.markerY != markerY ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Converts tap/drag position to percentage coordinates.
Offset percentFromLocal(Offset local, Size size) {
  final x = local.dx / size.width * 100;
  final y = local.dy / size.height * 100;
  return Offset(x, y);
}

/// Applies zone rules and clamps to the nearest valid point for [batsmanRuns].
Offset clampedPercentFromLocal(
  Offset local,
  Size size,
  int batsmanRuns,
) {
  final raw = percentFromLocal(local, size);
  return WagonWheelFieldGeometry.clampCoordinate(
    raw.dx,
    raw.dy,
    batsmanRuns,
  );
}
