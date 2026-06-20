import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_analytics_models.dart';
import 'insights_chart_widgets.dart';

enum _RunRateView { both, firstInnings, secondInnings }

/// Professional cumulative run rate progression chart.
class InsightsRunRateSection extends StatefulWidget {
  const InsightsRunRateSection({
    super.key,
    required this.data,
    required this.cf,
    this.phaseRanges,
  });

  final RunRateGraphData data;
  final CfColors cf;
  final MatchPhaseRanges? phaseRanges;

  @override
  State<InsightsRunRateSection> createState() => _InsightsRunRateSectionState();
}

class _InsightsRunRateSectionState extends State<InsightsRunRateSection> {
  _RunRateView _view = _RunRateView.both;

  RunRateInningsSeries? get _seriesA =>
      widget.data.innings.isNotEmpty ? widget.data.innings.first : null;

  RunRateInningsSeries? get _seriesB =>
      widget.data.innings.length > 1 ? widget.data.innings[1] : null;

  bool get _hasChartData {
    final series = widget.data.innings;
    return series.any((s) => s.points.any((p) => p.over > 0));
  }

  List<RunRateInningsSeries> get _visibleSeries {
    return switch (_view) {
      _RunRateView.both => [
          if (_seriesA != null) _seriesA!,
          if (_seriesB != null) _seriesB!,
        ],
      _RunRateView.firstInnings => [_seriesA!],
      _RunRateView.secondInnings => [_seriesB!],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.innings.isEmpty || !_hasChartData) {
      return const InsightsEmptyHint(
        message: 'Run rate data will appear after scoring begins.',
      );
    }

    final cf = widget.cf;
    final visible = _visibleSeries;
    final maxY = _niceMaxY(
      visible
          .expand((s) => s.points)
          .fold<double>(1, (m, p) => math.max(m, p.currentRunRate)),
    );
    final maxOver = widget.data.maxOverNumber.clamp(1, 999);
    final insights = widget.data.insightsFor(
      visible,
      phaseRanges: widget.phaseRanges,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_seriesB != null) ...[
          _ViewSelector(
            labelA: _seriesA!.shortLabel,
            labelB: _seriesB!.shortLabel,
            view: _view,
            onChanged: (v) => setState(() => _view = v),
            cf: cf,
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        Text(
          'Run Rate',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cf.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        SizedBox(
          height: 240,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cf.border),
              borderRadius: BorderRadius.circular(8),
              color: cf.card,
            ),
            child: _RunRateScrollChart(
              series: visible,
              maxY: maxY,
              maxOver: maxOver,
              colorA: cf.accent,
              colorB: cf.error,
              cf: cf,
              onPointTap: _showPointTooltip,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        _ChartLegend(
          cf: cf,
          showBoth: _view == _RunRateView.both && _seriesB != null,
          labelA: _seriesA?.shortLabel ?? 'Team A',
          labelB: _seriesB?.shortLabel ?? 'Team B',
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _TrendInsights(insights: insights, cf: cf),
        const SizedBox(height: AppDimens.spaceMd),
        _ChartFooter(cf: cf),
      ],
    );
  }

  double _niceMaxY(double maxRr) {
    if (maxRr <= 6) return 6;
    if (maxRr <= 9) return 9;
    if (maxRr <= 12) return 12;
    if (maxRr <= 15) return 15;
    return (maxRr / 3).ceil() * 3.0;
  }

  void _showPointTooltip(
    RunRateInningsSeries series,
    RunRatePoint point,
  ) {
    if (point.over <= 0) return;
    final cf = widget.cf;
    final overLabel = point.over == point.over.roundToDouble()
        ? '${point.over.round()}'
        : point.over.toStringAsFixed(1);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cf.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${series.label} · Over $overLabel',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: cf.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _tooltipRow('Runs', '${point.totalRuns}', cf),
            _tooltipRow('Wickets', '${point.wickets}', cf),
            _tooltipRow(
              'Current RR',
              point.currentRunRate.toStringAsFixed(2),
              cf,
            ),
            _tooltipRow('Partnership', '${point.partnershipRuns}', cf),
            _tooltipRow('Boundaries', '${point.boundaries}', cf),
            if (series.isChase && point.requiredRunRate != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              _tooltipRow(
                'Required RR',
                point.requiredRunRate!.toStringAsFixed(2),
                cf,
              ),
              _tooltipRow(
                'Difference',
                (point.requiredRunRate! - point.currentRunRate)
                    .toStringAsFixed(1),
                cf,
              ),
              _tooltipRow(
                point.requiredRunRate! > point.currentRunRate
                    ? 'Behind by'
                    : 'Ahead by',
                (point.requiredRunRate! - point.currentRunRate)
                    .abs()
                    .toStringAsFixed(1),
                cf,
              ),
            ],
            SizedBox(height: MediaQuery.paddingOf(ctx).bottom),
          ],
        ),
      ),
    );
  }

  Widget _tooltipRow(String label, String value, CfColors cf) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: cf.textSecondary)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cf.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({
    required this.labelA,
    required this.labelB,
    required this.view,
    required this.onChanged,
    required this.cf,
  });

  final String labelA;
  final String labelB;
  final _RunRateView view;
  final ValueChanged<_RunRateView> onChanged;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cf.border),
      ),
      child: Row(
        children: [
          _chip('Both', _RunRateView.both),
          _chip(labelA, _RunRateView.firstInnings),
          _chip(labelB, _RunRateView.secondInnings),
        ],
      ),
    );
  }

  Widget _chip(String label, _RunRateView value) {
    final selected = view == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? cf.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cf.textPrimary : cf.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.cf,
    required this.showBoth,
    required this.labelA,
    required this.labelB,
  });

  final CfColors cf;
  final bool showBoth;
  final String labelA;
  final String labelB;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _dot(cf.accent, labelA),
        if (showBoth) _dot(cf.error, labelB),
        _dot(cf.textPrimary, 'Wickets'),
      ],
    );
  }

  Widget _dot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: cf.textSecondary)),
      ],
    );
  }
}

class _RunRateScrollChart extends StatelessWidget {
  const _RunRateScrollChart({
    required this.series,
    required this.maxY,
    required this.maxOver,
    required this.colorA,
    required this.colorB,
    required this.cf,
    required this.onPointTap,
  });

  final List<RunRateInningsSeries> series;
  final double maxY;
  final int maxOver;
  final Color colorA;
  final Color colorB;
  final CfColors cf;
  final void Function(RunRateInningsSeries series, RunRatePoint point)
      onPointTap;

  @override
  Widget build(BuildContext context) {
    final minWidth = math.max(
      MediaQuery.sizeOf(context).width - 48,
      maxOver * 22.0 + 56,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: minWidth,
        height: 240,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapUp: (details) {
                final hit = _RunRateChartPainter.findPointAt(
                  position: details.localPosition,
                  size: constraints.biggest,
                  series: series,
                  maxY: maxY,
                  maxOver: maxOver,
                  colorA: colorA,
                  colorB: colorB,
                );
                if (hit != null) onPointTap(hit.$1, hit.$2);
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _RunRateChartPainter(
                  series: series,
                  maxY: maxY,
                  maxOver: maxOver,
                  colorA: colorA,
                  colorB: colorB,
                  cf: cf,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RunRateChartPainter extends CustomPainter {
  _RunRateChartPainter({
    required this.series,
    required this.maxY,
    required this.maxOver,
    required this.colorA,
    required this.colorB,
    required this.cf,
  });

  final List<RunRateInningsSeries> series;
  final double maxY;
  final int maxOver;
  final Color colorA;
  final Color colorB;
  final CfColors cf;

  static const _leftPad = 36.0;
  static const _rightPad = 16.0;
  static const _topPad = 20.0;
  static const _bottomPad = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;
    if (chartW <= 0 || chartH <= 0 || maxOver <= 0) return;

    final gridPaint = Paint()
      ..color = cf.border.withValues(alpha: cf.isLight ? 1 : 0.5)
      ..strokeWidth = 1;

    for (var tick = 0.0; tick <= maxY; tick += 3) {
      final y = _topPad + chartH - (tick / maxY) * chartH;
      _drawDashedLine(
        canvas,
        Offset(_leftPad, y),
        Offset(_leftPad + chartW, y),
        gridPaint,
      );
      _drawLabel(canvas, tick.toStringAsFixed(0), _leftPad - 8, y, cf.textSecondary);
    }

    final rrLabel = TextPainter(
      text: TextSpan(
        text: 'RR',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: cf.textSecondary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rrLabel.paint(canvas, const Offset(2, _topPad - 12));

    canvas.drawLine(
      Offset(_leftPad, _topPad + chartH),
      Offset(_leftPad + chartW, _topPad + chartH),
      gridPaint,
    );

    for (var over = 1; over <= maxOver; over++) {
      final x = _xForOver(over.toDouble(), chartW);
      _drawLabel(
        canvas,
        '$over',
        _leftPad + x,
        _topPad + chartH + 8,
        cf.textSecondary,
        center: true,
      );
    }
    _drawLabel(
      canvas,
      'Ovs',
      _leftPad + chartW + 2,
      _topPad + chartH + 6,
      cf.textSecondary,
    );

    for (var i = 0; i < series.length; i++) {
      final color = i == 0 ? colorA : colorB;
      final pts = series[i].points;
      if (pts.length < 2) continue;

      final offsets = pts
          .map((p) => Offset(_leftPad + _xForOver(p.over, chartW), _yForRr(p.currentRunRate, chartH)))
          .toList();

      _drawSmoothLine(canvas, offsets, color);
      for (var j = 0; j < pts.length; j++) {
        final p = pts[j];
        final center = offsets[j];
        canvas.drawCircle(center, 3.5, Paint()..color = color);
        canvas.drawCircle(
          center,
          3.5,
          Paint()
            ..color = cf.card
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        if (p.wicketsInOver > 0) {
          final marker = p.wicketsInOver == 1
              ? 'W'
              : p.wicketsInOver == 2
                  ? '2W'
                  : '${p.wicketsInOver}W';
          _drawLabel(
            canvas,
            marker,
            center.dx,
            center.dy - 14,
            cf.textPrimary,
            center: true,
            fontSize: 8,
            bold: true,
          );
        }
      }
    }
  }

  double _xForOver(double over, double chartW) => (over / maxOver) * chartW;

  double _yForRr(double rr, double chartH) =>
      _topPad + chartH - (rr.clamp(0, maxY) / maxY) * chartH;

  void _drawSmoothLine(Canvas canvas, List<Offset> points, Color color) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cp1 = Offset((p0.dx + p1.dx) / 2, p0.dy);
      final cp2 = Offset((p0.dx + p1.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color, {
    bool center = false,
    double fontSize = 9,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center ? x - tp.width / 2 : x - tp.width, y - tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 4.0;
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

  static (RunRateInningsSeries, RunRatePoint)? findPointAt({
    required Offset position,
    required Size size,
    required List<RunRateInningsSeries> series,
    required double maxY,
    required int maxOver,
    required Color colorA,
    required Color colorB,
  }) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;
    if (chartW <= 0 || chartH <= 0) return null;

    (RunRateInningsSeries, RunRatePoint)? closest;
    var bestDist = 999.0;

    for (final s in series) {
      for (final p in s.points) {
        if (p.over <= 0) continue;
        final x = _leftPad + (p.over / maxOver) * chartW;
        final y = _topPad + chartH - (p.currentRunRate.clamp(0, maxY) / maxY) * chartH;
        final d = (position - Offset(x, y)).distance;
        if (d < 18 && d < bestDist) {
          bestDist = d;
          closest = (s, p);
        }
      }
    }
    return closest;
  }

  @override
  bool shouldRepaint(covariant _RunRateChartPainter oldDelegate) => true;
}

class _TrendInsights extends StatelessWidget {
  const _TrendInsights({required this.insights, required this.cf});

  final RunRateTrendInsights insights;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Highest RR', insights.highestRunRateLabel),
      ('Lowest RR', insights.lowestRunRateLabel),
      ('Best Acceleration', insights.bestAccelerationLabel),
      ('Biggest Slowdown', insights.biggestSlowdownLabel),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return SizedBox(
              width: cellW,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: cfCardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: TextStyle(fontSize: 10, color: cf.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ChartFooter extends StatelessWidget {
  const _ChartFooter({required this.cf});

  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    const lines = [
      'This graph shows cumulative run rate progression.',
      'Tap any point for detailed analysis.',
      'Wicket markers indicate wickets lost during that phase.',
      'Compare innings momentum over time.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $line',
                style: TextStyle(fontSize: 11, color: cf.textSecondary),
              ),
            ),
          )
          .toList(),
    );
  }
}
