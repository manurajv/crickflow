import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../data/models/wagon_wheel_data.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_colors.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';

/// Draws a top-down cricket ground with pitch centre and shot lines.
class WagonWheelGroundPainter extends CustomPainter {
  WagonWheelGroundPainter({
    required this.shots,
    this.viewMode = WagonWheelViewMode.lines,
    this.showPitchCenter = true,
    this.maxShotsToRender = 500,
  });

  final List<WagonWheelShotPoint> shots;
  final WagonWheelViewMode viewMode;
  final bool showPitchCenter;
  final int maxShotsToRender;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGround(canvas, size);

    final center = Offset(
      size.width * WagonWheelData.pitchCenterX / 100,
      size.height * WagonWheelData.pitchCenterY / 100,
    );

    if (showPitchCenter) {
      canvas.drawCircle(
        center,
        4,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        center,
        6,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final renderShots = shots.length > maxShotsToRender
        ? shots.sublist(shots.length - maxShotsToRender)
        : shots;

    switch (viewMode) {
      case WagonWheelViewMode.heatmap:
        _paintHeatmap(canvas, size, renderShots);
        break;
      case WagonWheelViewMode.scatter:
        _paintScatter(canvas, size, center, renderShots);
        break;
      case WagonWheelViewMode.lines:
        _paintLines(canvas, size, center, renderShots);
        break;
    }
  }

  void _paintGround(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outfield = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      outfield,
    );

    final pitchW = size.width * 0.08;
    final pitchH = size.height * 0.42;
    final pitchRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: pitchW,
      height: pitchH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitchRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF8D6E63),
    );

    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final creaseY1 = pitchRect.top + pitchH * 0.12;
    final creaseY2 = pitchRect.bottom - pitchH * 0.12;
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

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.38,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.22,
      ringPaint,
    );
  }

  void _paintLines(
    Canvas canvas,
    Size size,
    Offset center,
    List<WagonWheelShotPoint> renderShots,
  ) {
    for (final shot in renderShots) {
      final end = _offsetForShot(size, shot.wagonWheel);
      final color = WagonWheelColors.forBatsmanRuns(shot.batsmanRuns);
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = shot.batsmanRuns >= 4 ? 2.2 : 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, end, linePaint);
      canvas.drawCircle(end, 3.5, Paint()..color = color);
    }
  }

  void _paintScatter(
    Canvas canvas,
    Size size,
    Offset center,
    List<WagonWheelShotPoint> renderShots,
  ) {
    for (final shot in renderShots) {
      final end = _offsetForShot(size, shot.wagonWheel);
      final color = WagonWheelColors.forBatsmanRuns(shot.batsmanRuns);
      canvas.drawCircle(
        end,
        shot.batsmanRuns >= 4 ? 5 : 3.5,
        Paint()..color = color,
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
      final col = (shot.wagonWheel.x / 100 * grid).floor().clamp(0, grid - 1);
      final row = (shot.wagonWheel.y / 100 * grid).floor().clamp(0, grid - 1);
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

  Offset _offsetForShot(Size size, WagonWheelData ww) {
    return Offset(
      size.width * ww.x / 100,
      size.height * ww.y / 100,
    );
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
  });

  final double markerX;
  final double markerY;

  @override
  void paint(Canvas canvas, Size size) {
    WagonWheelGroundPainter(
      shots: const [],
      showPitchCenter: true,
    ).paint(canvas, size);

    final marker = Offset(
      size.width * markerX / 100,
      size.height * markerY / 100,
    );
    final center = Offset(
      size.width * WagonWheelData.pitchCenterX / 100,
      size.height * WagonWheelData.pitchCenterY / 100,
    );

    final previewPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, marker, previewPaint);

    canvas.drawCircle(
      marker,
      10,
      Paint()
        ..color = const Color(0xFFFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      marker,
      5,
      Paint()..color = const Color(0xFFFFC107),
    );
  }

  @override
  bool shouldRepaint(covariant WagonWheelSelectionPainter oldDelegate) {
    return oldDelegate.markerX != markerX || oldDelegate.markerY != markerY;
  }
}

/// Converts tap/drag position to percentage coordinates clamped inside ground.
Offset percentFromLocal(Offset local, Size size) {
  final x = (local.dx / size.width * 100).clamp(2.0, 98.0);
  final y = (local.dy / size.height * 100).clamp(2.0, 98.0);
  return Offset(x, y);
}

double distanceFromCenter(double x, double y) {
  final dx = x - WagonWheelData.pitchCenterX;
  final dy = y - WagonWheelData.pitchCenterY;
  return math.sqrt(dx * dx + dy * dy);
}
