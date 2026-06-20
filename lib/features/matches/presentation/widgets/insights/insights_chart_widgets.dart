import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';

/// Collapsible insights section — chart content loads only when expanded.
class InsightsCollapsibleSection extends StatefulWidget {
  const InsightsCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<InsightsCollapsibleSection> createState() =>
      _InsightsCollapsibleSectionState();
}

class _InsightsCollapsibleSectionState extends State<InsightsCollapsibleSection> {
  late bool _expanded;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _loaded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceXs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            0,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
          ),
          onExpansionChanged: (value) {
            setState(() {
              _expanded = value;
              if (value) _loaded = true;
            });
          },
          title: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
          ),
          subtitle: widget.subtitle != null
              ? Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                )
              : null,
          iconColor: cf.accent,
          collapsedIconColor: cf.textSecondary,
          children: [
            if (_loaded && _expanded) widget.child,
          ],
        ),
      ),
    );
  }
}

class InsightsEmptyHint extends StatelessWidget {
  const InsightsEmptyHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.cf.textSecondary,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class InsightsPieChart extends StatelessWidget {
  const InsightsPieChart({
    super.key,
    required this.slices,
    this.size = 140,
  });

  final List<({String label, double value, Color color})> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      return InsightsEmptyHint(message: 'No data yet');
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiePainter(slices: slices, total: total),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.slices, required this.total});

  final List<({String label, double value, Color color})> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }
    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.22,
      holePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}

class InsightsLegend extends StatelessWidget {
  const InsightsLegend({super.key, required this.items});

  final List<({Color color, String label, String value})> items;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(fontSize: 12, color: cf.textSecondary),
                ),
              ),
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class InsightsLineChart extends StatelessWidget {
  const InsightsLineChart({
    super.key,
    required this.series,
    this.height = 180,
    this.targetLine,
    this.yLabel,
  });

  final List<InsightsLineSeries> series;
  final double height;
  final double? targetLine;
  final String Function(double)? yLabel;

  @override
  Widget build(BuildContext context) {
    if (series.every((s) => s.points.isEmpty)) {
      return const InsightsEmptyHint(message: 'No progression data yet');
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _LineChartPainter(
          series: series,
          targetLine: targetLine,
          cf: context.cf,
          yLabel: yLabel,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class InsightsLineSeries {
  const InsightsLineSeries({
    required this.label,
    required this.points,
    required this.color,
    this.markers = const [],
  });

  final String label;
  final List<Offset> points;
  final Color color;
  final List<Offset> markers;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.cf,
    this.targetLine,
    this.yLabel,
  });

  final List<InsightsLineSeries> series;
  final CfColors cf;
  final double? targetLine;
  final String Function(double)? yLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 36.0;
    const padRight = 8.0;
    const padTop = 8.0;
    const padBottom = 24.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    var maxX = 1.0;
    var maxY = 1.0;
    for (final s in series) {
      for (final p in s.points) {
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    if (targetLine != null && targetLine! > maxY) maxY = targetLine!;
    maxY *= 1.1;
    maxX = maxX < 1 ? 1 : maxX;

    final gridPaint = Paint()
      ..color = cf.border
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(padLeft, padTop + chartH),
      Offset(padLeft + chartW, padTop + chartH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(padLeft, padTop),
      Offset(padLeft, padTop + chartH),
      gridPaint,
    );

    if (targetLine != null) {
      final y = padTop + chartH - (targetLine! / maxY) * chartH;
      final dashPaint = Paint()
        ..color = cf.statusUpcoming
        ..strokeWidth = 1.5;
      _drawDashedLine(
        canvas,
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        dashPaint,
      );
    }

    for (final s in series) {
      if (s.points.length < 2) continue;
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final p = s.points[i];
        final x = padLeft + (p.dx / maxX) * chartW;
        final y = padTop + chartH - (p.dy / maxY) * chartH;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, linePaint);

      for (final m in s.markers) {
        final x = padLeft + (m.dx / maxX) * chartW;
        final y = padTop + chartH - (m.dy / maxY) * chartH;
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = cf.error,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    final dx = end.dx - start.dx;
    final dist = dx.abs();
    var drawn = 0.0;
    while (drawn < dist) {
      final x1 = start.dx + drawn;
      final x2 = (x1 + dash).clamp(start.dx, end.dx);
      canvas.drawLine(Offset(x1, start.dy), Offset(x2, start.dy), paint);
      drawn += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

class InsightsBarChart extends StatelessWidget {
  const InsightsBarChart({
    super.key,
    required this.bars,
    this.height = 160,
    this.colorForBar,
  });

  final List<({int over, int runs, Color color, bool highlight})> bars;
  final double height;
  final Color Function(int over, int runs)? colorForBar;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const InsightsEmptyHint(message: 'No over data yet');
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BarChartPainter(bars: bars, cf: context.cf),
        size: Size.infinite,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.bars, required this.cf});

  final List<({int over, int runs, Color color, bool highlight})> bars;
  final CfColors cf;

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 8.0;
    const padBottom = 20.0;
    const padTop = 8.0;
    final chartH = size.height - padBottom - padTop;
    final maxRuns = bars.fold<int>(1, (m, b) => math.max(m, b.runs));
    final barW = (size.width - padLeft * 2) / bars.length;

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final h = (bar.runs / maxRuns) * chartH;
      final x = padLeft + i * barW + barW * 0.15;
      final w = barW * 0.7;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, padTop + chartH - h, w, h),
        const Radius.circular(3),
      );
      final paint = Paint()..color = bar.color;
      canvas.drawRRect(rect, paint);
      if (bar.highlight) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = cf.textPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class InsightsHorizontalBars extends StatelessWidget {
  const InsightsHorizontalBars({
    super.key,
    required this.items,
    this.maxValue,
  });

  final List<({
    String label,
    double value,
    String trailing,
    Color? color,
    bool highlight,
  })> items;
  final double? maxValue;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const InsightsEmptyHint(message: 'No data yet');
    }
    final cf = context.cf;
    final max = maxValue ??
        items.fold<double>(0, (m, e) => math.max(m, e.value)).clamp(1, double.infinity);

    return Column(
      children: items.map((item) {
        final color = item.color ?? cf.accent;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            item.highlight ? FontWeight.w700 : FontWeight.w500,
                        color: cf.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    item.trailing,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.highlight ? cf.success : cf.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.value / max,
                  minHeight: 8,
                  backgroundColor: cf.surfaceElevated,
                  color: item.highlight ? cf.success : color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
