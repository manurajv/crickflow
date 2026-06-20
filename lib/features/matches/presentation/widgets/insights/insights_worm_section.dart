import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_analytics_models.dart';
import '../../../../../shared/widgets/stat_grid.dart';
import 'insights_chart_widgets.dart';

enum _WormView { both, firstInnings, secondInnings }

/// Professional cumulative score worm chart.
class InsightsWormSection extends StatefulWidget {
  const InsightsWormSection({
    super.key,
    required this.data,
    required this.cf,
    this.phaseRanges,
    this.isTestMatch = false,
  });

  final WormGraphData data;
  final CfColors cf;
  final MatchPhaseRanges? phaseRanges;
  final bool isTestMatch;

  @override
  State<InsightsWormSection> createState() => _InsightsWormSectionState();
}

class _InsightsWormSectionState extends State<InsightsWormSection> {
  _WormView _view = _WormView.both;

  WormInningsSeries? get _seriesA =>
      widget.data.innings.isNotEmpty ? widget.data.innings.first : null;

  WormInningsSeries? get _seriesB =>
      widget.data.innings.length > 1 ? widget.data.innings[1] : null;

  bool get _hasChartData =>
      widget.data.innings.any((s) => s.points.any((p) => p.over > 0));

  List<WormInningsSeries> get _visibleSeries => switch (_view) {
        _WormView.both => [
            ?_seriesA,
            ?_seriesB,
          ],
        _WormView.firstInnings => [_seriesA!],
        _WormView.secondInnings => [_seriesB!],
      };

  @override
  Widget build(BuildContext context) {
    if (widget.data.innings.isEmpty || !_hasChartData) {
      return const InsightsEmptyHint(
        message: 'Worm chart will appear after scoring begins.',
      );
    }

    final cf = widget.cf;
    final visible = _visibleSeries;
    final maxY = _niceMaxY(
      visible
          .expand((s) => s.points)
          .fold<int>(1, (m, p) => math.max(m, p.runs)),
    );
    final maxOver = widget.data.maxOverNumber.clamp(1, 999);
    final insights = widget.data.insightsFor(
      visible,
      phaseRanges: widget.phaseRanges,
      isTestMatch: widget.isTestMatch,
    );
    final showChaseTarget = visible.any((s) => s.isChase) &&
        widget.data.targetLine != null;

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
        if (_view != _WormView.both) ...[
          _SummaryCards(visible: visible, cf: cf),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        SizedBox(
          height: 260,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cf.border),
              borderRadius: BorderRadius.circular(8),
              color: cf.card,
            ),
            child: _WormScrollChart(
              series: visible,
              maxY: maxY,
              maxOver: maxOver,
              targetLine: showChaseTarget ? widget.data.targetLine : null,
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
          showBoth: _view == _WormView.both && _seriesB != null,
          labelA: _seriesA?.shortLabel ?? 'Team A',
          labelB: _seriesB?.shortLabel ?? 'Team B',
          showTarget: showChaseTarget,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _AutoInsights(insights: insights, cf: cf, isTestMatch: widget.isTestMatch),
        const SizedBox(height: AppDimens.spaceMd),
        _ChartFooter(cf: cf),
      ],
    );
  }

  int _niceMaxY(int maxRuns) {
    if (maxRuns <= 40) return 40;
    if (maxRuns <= 80) return 80;
    if (maxRuns <= 120) return 120;
    if (maxRuns <= 160) return 160;
    if (maxRuns <= 200) return 200;
    return ((maxRuns / 40).ceil() * 40);
  }

  void _showPointTooltip(WormInningsSeries series, WormPoint point) {
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
            _tooltipRow('Score', '${point.runs}/${point.wickets}', cf),
            _tooltipRow('Runs in Over', '${point.runsInOver}', cf),
            _tooltipRow(
              'Current RR',
              point.currentRunRate.toStringAsFixed(2),
              cf,
            ),
            _tooltipRow('Wickets', '${point.wickets}', cf),
            _tooltipRow('Partnership', '${point.partnershipRuns}', cf),
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

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.visible, required this.cf});

  final List<WormInningsSeries> visible;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (visible.length == 1) {
      final s = visible.first;
      return StatGrid(
        cells: [
          StatCellData(value: s.summary.finalScoreLabel, label: 'Final Score'),
          StatCellData(value: s.summary.highestOverLabel, label: 'Highest Over'),
          StatCellData(
            value: s.summary.averageOverLabel,
            label: 'Average Over',
          ),
        ],
      );
    }

    return Column(
      children: visible.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: StatGrid(
            cells: [
              StatCellData(
                value: s.summary.finalScoreLabel,
                label: '${s.shortLabel} Score',
              ),
              StatCellData(
                value: s.summary.highestOverLabel,
                label: 'Highest Over',
              ),
              StatCellData(
                value: s.summary.averageOverLabel,
                label: 'Avg Over',
              ),
            ],
          ),
        );
      }).toList(),
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
  final _WormView view;
  final ValueChanged<_WormView> onChanged;
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
          _chip('Both', _WormView.both),
          _chip(labelA, _WormView.firstInnings),
          _chip(labelB, _WormView.secondInnings),
        ],
      ),
    );
  }

  Widget _chip(String label, _WormView value) {
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
    required this.showTarget,
  });

  final CfColors cf;
  final bool showBoth;
  final String labelA;
  final String labelB;
  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _dot(cf.accent, labelA),
        if (showBoth) _dot(cf.error, labelB),
        _dot(cf.textPrimary, 'Wickets'),
        if (showTarget) _dashed('Target'),
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

  Widget _dashed(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 2,
          child: CustomPaint(painter: _MiniDashPainter(cf.textSecondary)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: cf.textSecondary)),
      ],
    );
  }
}

class _MiniDashPainter extends CustomPainter {
  _MiniDashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WormScrollChart extends StatelessWidget {
  const _WormScrollChart({
    required this.series,
    required this.maxY,
    required this.maxOver,
    required this.targetLine,
    required this.colorA,
    required this.colorB,
    required this.cf,
    required this.onPointTap,
  });

  final List<WormInningsSeries> series;
  final int maxY;
  final int maxOver;
  final int? targetLine;
  final Color colorA;
  final Color colorB;
  final CfColors cf;
  final void Function(WormInningsSeries series, WormPoint point) onPointTap;

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
        height: 260,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapUp: (details) {
                final hit = _WormChartPainter.findPointAt(
                  position: details.localPosition,
                  size: constraints.biggest,
                  series: series,
                  maxY: maxY,
                  maxOver: maxOver,
                );
                if (hit != null) onPointTap(hit.$1, hit.$2);
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _WormChartPainter(
                  series: series,
                  maxY: maxY,
                  maxOver: maxOver,
                  targetLine: targetLine,
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

class _WormChartPainter extends CustomPainter {
  _WormChartPainter({
    required this.series,
    required this.maxY,
    required this.maxOver,
    required this.targetLine,
    required this.colorA,
    required this.colorB,
    required this.cf,
  });

  final List<WormInningsSeries> series;
  final int maxY;
  final int maxOver;
  final int? targetLine;
  final Color colorA;
  final Color colorB;
  final CfColors cf;

  static const _leftPad = 40.0;
  static const _rightPad = 16.0;
  static const _topPad = 26.0;
  static const _bottomPad = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;
    if (chartW <= 0 || chartH <= 0 || maxOver <= 0) return;

    final gridPaint = Paint()
      ..color = cf.border.withValues(alpha: cf.isLight ? 1 : 0.5)
      ..strokeWidth = 1;

    for (var tick = 0; tick <= maxY; tick += 40) {
      final y = _topPad + chartH - (tick / maxY) * chartH;
      _drawDashedLine(
        canvas,
        Offset(_leftPad, y),
        Offset(_leftPad + chartW, y),
        gridPaint,
      );
      _drawLabel(canvas, '$tick', _leftPad - 6, y, cf.textSecondary);
    }

    _drawLeftLabel(canvas, 'Runs', 4, 4, cf.textSecondary);

    canvas.drawLine(
      Offset(_leftPad, _topPad + chartH),
      Offset(_leftPad + chartW, _topPad + chartH),
      gridPaint,
    );

    for (var over = 1; over <= maxOver; over++) {
      final x = _leftPad + (over / maxOver) * chartW;
      _drawLabel(canvas, '$over', x, _topPad + chartH + 8, cf.textSecondary,
          center: true);
    }
    _drawLabel(
      canvas,
      'Ovs',
      _leftPad + chartW + 2,
      _topPad + chartH + 6,
      cf.textSecondary,
    );

    if (targetLine != null && targetLine! > 0) {
      final y = _topPad + chartH - (targetLine!.clamp(0, maxY) / maxY) * chartH;
      _drawDashedLine(
        canvas,
        Offset(_leftPad, y),
        Offset(_leftPad + chartW, y),
        Paint()
          ..color = cf.textSecondary.withValues(alpha: 0.6)
          ..strokeWidth = 1.5,
      );
      final chasePath = Path()
        ..moveTo(_leftPad, _topPad + chartH)
        ..lineTo(_leftPad + chartW, y);
      canvas.drawPath(
        chasePath,
        Paint()
          ..color = cf.textMuted.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    for (var i = 0; i < series.length; i++) {
      final color = i == 0 ? colorA : colorB;
      final pts = series[i].points;
      if (pts.length < 2) continue;

      final offsets = pts
          .map(
            (p) => Offset(
              _leftPad + (p.over / maxOver) * chartW,
              _topPad + chartH - (p.runs.clamp(0, maxY) / maxY) * chartH,
            ),
          )
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

  void _drawLeftLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color, {
    double fontSize = 10,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
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
    tp.paint(
      canvas,
      Offset(center ? x - tp.width / 2 : x - tp.width, y - tp.height / 2),
    );
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

  static (WormInningsSeries, WormPoint)? findPointAt({
    required Offset position,
    required Size size,
    required List<WormInningsSeries> series,
    required int maxY,
    required int maxOver,
  }) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;
    if (chartW <= 0 || chartH <= 0) return null;

    (WormInningsSeries, WormPoint)? closest;
    var bestDist = 999.0;

    for (final s in series) {
      for (final p in s.points) {
        if (p.over <= 0) continue;
        final x = _leftPad + (p.over / maxOver) * chartW;
        final y = _topPad + chartH - (p.runs.clamp(0, maxY) / maxY) * chartH;
        final d = (position - Offset(x, y)).distance;
        if (d < 20 && d < bestDist) {
          bestDist = d;
          closest = (s, p);
        }
      }
    }
    return closest;
  }

  @override
  bool shouldRepaint(covariant _WormChartPainter oldDelegate) => true;
}

class _AutoInsights extends StatelessWidget {
  const _AutoInsights({
    required this.insights,
    required this.cf,
    this.isTestMatch = false,
  });

  final WormAutoInsights insights;
  final CfColors cf;
  final bool isTestMatch;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Highest Scoring Phase', insights.highestScoringPhaseLabel),
      if (!isTestMatch) ('Best Start', insights.bestStartLabel),
      if (!isTestMatch) ('Best Finish', insights.bestFinishLabel),
      ('Fastest Acceleration', insights.fastestAccelerationLabel),
    ].where((item) => item.$2 != '—').toList();

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
                      maxLines: 3,
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
      'This graph shows cumulative score progression throughout the innings.',
      'Tap any point for detailed over analysis.',
      'Wicket markers indicate wickets lost.',
      'Compare scoring momentum across innings.',
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
