import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_analytics_models.dart';
import 'insights_chart_widgets.dart';

enum _ManhattanView { both, firstInnings, secondInnings }

/// Professional over-by-over Manhattan comparison chart.
class InsightsManhattanSection extends StatefulWidget {
  const InsightsManhattanSection({
    super.key,
    required this.data,
    required this.cf,
    this.ballsPerOver = 6,
    this.phaseRanges,
    this.isTestMatch = false,
  });

  final ManhattanChartData data;
  final CfColors cf;
  final int ballsPerOver;
  final MatchPhaseRanges? phaseRanges;
  final bool isTestMatch;

  @override
  State<InsightsManhattanSection> createState() =>
      _InsightsManhattanSectionState();
}

class _InsightsManhattanSectionState extends State<InsightsManhattanSection> {
  _ManhattanView _view = _ManhattanView.both;

  ManhattanInningsSeries? get _seriesA =>
      widget.data.innings.isNotEmpty ? widget.data.innings.first : null;

  ManhattanInningsSeries? get _seriesB =>
      widget.data.innings.length > 1 ? widget.data.innings[1] : null;

  @override
  Widget build(BuildContext context) {
    if (widget.data.innings.isEmpty) {
      return const InsightsEmptyHint(message: 'No over-by-over data yet');
    }

    final cf = widget.cf;
    final primary = _view == _ManhattanView.secondInnings ? _seriesB : _seriesA;
    final secondary = _view == _ManhattanView.both ? _seriesB : null;
    final showBoth = _view == _ManhattanView.both && _seriesB != null;

    final groups = _buildGroups(showBoth, primary, secondary);
    if (groups.isEmpty) {
      return const InsightsEmptyHint(message: 'No over-by-over data yet');
    }

    final maxRuns = groups.fold<int>(1, (m, g) {
      final a = g.inningsA?.runs ?? 0;
      final b = g.inningsB?.runs ?? 0;
      return math.max(m, math.max(a, b));
    });
    final maxY = _niceMaxY(maxRuns);

    final insights = switch (_view) {
      _ManhattanView.both => widget.data.insightsFor(
          primary: _seriesA,
          secondary: _seriesB,
          ballsPerOver: widget.ballsPerOver,
          phaseRanges: widget.phaseRanges,
          isTestMatch: widget.isTestMatch,
        ),
      _ManhattanView.firstInnings => widget.data.insightsFor(
          primary: _seriesA,
          ballsPerOver: widget.ballsPerOver,
          phaseRanges: widget.phaseRanges,
          isTestMatch: widget.isTestMatch,
        ),
      _ManhattanView.secondInnings => widget.data.insightsFor(
          primary: _seriesB,
          ballsPerOver: widget.ballsPerOver,
          phaseRanges: widget.phaseRanges,
          isTestMatch: widget.isTestMatch,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_seriesB != null) ...[
          _ViewSelector(
            seriesA: _seriesA!,
            seriesB: _seriesB!,
            view: _view,
            onChanged: (v) => setState(() => _view = v),
            cf: cf,
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        SizedBox(
          height: 240,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cf.border),
              borderRadius: BorderRadius.circular(8),
              color: cf.card,
            ),
            child: _ManhattanScrollChart(
            groups: groups,
            maxY: maxY,
            showBoth: showBoth,
            avgRrA: primary?.averageRunRate ?? 0,
            avgRrB: showBoth ? (_seriesB?.averageRunRate ?? 0) : 0,
            colorA: cf.accent,
            colorB: cf.error,
            labelA: primary?.shortLabel ?? 'Team A',
            labelB: _seriesB?.shortLabel ?? 'Team B',
            cf: cf,
            onOverTap: _showOverTooltip,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        _ChartLegend(cf: cf, showBoth: showBoth, seriesA: _seriesA, seriesB: _seriesB),
        const SizedBox(height: AppDimens.spaceMd),
        _MomentumInsights(
          insights: insights,
          cf: cf,
          isTestMatch: widget.isTestMatch,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _ChartFooter(cf: cf),
      ],
    );
  }

  List<ManhattanComparisonGroup> _buildGroups(
    bool showBoth,
    ManhattanInningsSeries? primary,
    ManhattanInningsSeries? secondary,
  ) {
    if (showBoth) return widget.data.comparisonGroups();

    final source = primary;
    if (source == null) return const [];
    return source.overs
        .map(
          (o) => ManhattanComparisonGroup(
            overNumber: o.overNumber,
            inningsA: o,
          ),
        )
        .toList();
  }

  int _niceMaxY(int maxRuns) {
    if (maxRuns <= 4) return 4;
    if (maxRuns <= 8) return 8;
    if (maxRuns <= 12) return 12;
    if (maxRuns <= 16) return 16;
    if (maxRuns <= 20) return 20;
    if (maxRuns <= 24) return 24;
    return ((maxRuns / 4).ceil() * 4);
  }

  void _showOverTooltip(
    int over,
    ManhattanOverDetail detail,
    String teamLabel,
  ) {
    final cf = widget.cf;
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
              '$teamLabel · Over $over',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: cf.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _tooltipRow('Runs', '${detail.runs}', cf),
            _tooltipRow('Wickets', '${detail.wickets}', cf),
            _tooltipRow('Run Rate', detail.runRate.toStringAsFixed(2), cf),
            _tooltipRow('Boundary Runs', '${detail.boundaryRuns}', cf),
            _tooltipRow('Singles', '${detail.singles}', cf),
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
    required this.seriesA,
    required this.seriesB,
    required this.view,
    required this.onChanged,
    required this.cf,
  });

  final ManhattanInningsSeries seriesA;
  final ManhattanInningsSeries seriesB;
  final _ManhattanView view;
  final ValueChanged<_ManhattanView> onChanged;
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
          _chip('Both', _ManhattanView.both),
          _chip(seriesA.shortLabel, _ManhattanView.firstInnings),
          _chip(seriesB.shortLabel, _ManhattanView.secondInnings),
        ],
      ),
    );
  }

  Widget _chip(String label, _ManhattanView value) {
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
    required this.seriesA,
    required this.seriesB,
  });

  final CfColors cf;
  final bool showBoth;
  final ManhattanInningsSeries? seriesA;
  final ManhattanInningsSeries? seriesB;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _item(cf.accent, showBoth ? (seriesA?.shortLabel ?? 'Team A') : 'Runs'),
        if (showBoth) _item(cf.error, seriesB?.shortLabel ?? 'Team B'),
        _item(cf.textPrimary, 'Wickets', isDot: true),
        _dashedItem('Avg RR'),
      ],
    );
  }

  Widget _item(Color color, String label, {bool isDot = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isDot ? color : color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: cf.textSecondary)),
      ],
    );
  }

  Widget _dashedItem(String label) {
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
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManhattanScrollChart extends StatelessWidget {
  const _ManhattanScrollChart({
    required this.groups,
    required this.maxY,
    required this.showBoth,
    required this.avgRrA,
    required this.avgRrB,
    required this.colorA,
    required this.colorB,
    required this.labelA,
    required this.labelB,
    required this.cf,
    required this.onOverTap,
  });

  final List<ManhattanComparisonGroup> groups;
  final int maxY;
  final bool showBoth;
  final double avgRrA;
  final double avgRrB;
  final Color colorA;
  final Color colorB;
  final String labelA;
  final String labelB;
  final CfColors cf;
  final void Function(int over, ManhattanOverDetail detail, String teamLabel)
      onOverTap;

  @override
  Widget build(BuildContext context) {
    const groupWidth = 40.0;
    const leftPad = 36.0;
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 48,
      groups.length * groupWidth + leftPad + 8,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: 240,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapUp: (details) {
                final hit = _hitTest(
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
                if (hit == null) return;
                onOverTap(hit.$1, hit.$2, hit.$3);
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ManhattanChartPainter(
                  groups: groups,
                  maxY: maxY,
                  showBoth: showBoth,
                  avgRrA: avgRrA,
                  avgRrB: avgRrB,
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

  (int, ManhattanOverDetail, String)? _hitTest(double x, double width) {
    const leftPad = 36.0;
    const rightPad = 8.0;
    if (x < leftPad || groups.isEmpty) return null;
    final chartW = width - leftPad - rightPad;
    final groupW = chartW / groups.length;
    final idx = ((x - leftPad) / groupW).floor();
    if (idx < 0 || idx >= groups.length) return null;
    final g = groups[idx];
    final cx = leftPad + idx * groupW + groupW / 2;

    if (showBoth) {
      if (g.inningsA != null && x <= cx) {
        return (g.overNumber, g.inningsA!, labelA);
      }
      if (g.inningsB != null && x > cx) {
        return (g.overNumber, g.inningsB!, labelB);
      }
      return g.inningsA != null
          ? (g.overNumber, g.inningsA!, labelA)
          : g.inningsB != null
              ? (g.overNumber, g.inningsB!, labelB)
              : null;
    }

    if (g.inningsA != null) {
      return (g.overNumber, g.inningsA!, labelA);
    }
    return null;
  }
}

class _ManhattanChartPainter extends CustomPainter {
  _ManhattanChartPainter({
    required this.groups,
    required this.maxY,
    required this.showBoth,
    required this.avgRrA,
    required this.avgRrB,
    required this.colorA,
    required this.colorB,
    required this.cf,
  });

  final List<ManhattanComparisonGroup> groups;
  final int maxY;
  final bool showBoth;
  final double avgRrA;
  final double avgRrB;
  final Color colorA;
  final Color colorB;
  final CfColors cf;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 36.0;
    const rightPad = 8.0;
    const topPad = 20.0;
    const bottomPad = 28.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (groups.isEmpty || chartH <= 0) return;

    final gridPaint = Paint()
      ..color = cf.border.withValues(alpha: cf.isLight ? 1 : 0.5)
      ..strokeWidth = 1;

    final ySteps = _yTicks(maxY);
    for (final tick in ySteps) {
      final y = topPad + chartH - (tick / maxY) * chartH;
      _drawDashedLine(
        canvas,
        Offset(leftPad, y),
        Offset(leftPad + chartW, y),
        gridPaint,
      );
      _drawYLabel(canvas, tick, leftPad, y, cf.textSecondary);
    }

    final runsLabel = TextPainter(
      text: TextSpan(
        text: 'Runs',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: cf.textSecondary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    runsLabel.paint(canvas, Offset(2, topPad - 12));

    canvas.drawLine(
      Offset(leftPad, topPad + chartH),
      Offset(leftPad + chartW, topPad + chartH),
      gridPaint,
    );

    if (avgRrA > 0) {
      _drawAvgLine(canvas, leftPad, chartW, topPad, chartH, avgRrA, colorA);
    }
    if (showBoth && avgRrB > 0) {
      _drawAvgLine(canvas, leftPad, chartW, topPad, chartH, avgRrB, colorB);
    }

    final groupW = chartW / groups.length;
    final barW = showBoth ? groupW * 0.22 : groupW * 0.45;

    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final cx = leftPad + i * groupW + groupW / 2;

      if (showBoth) {
        if (g.inningsA != null) {
          _drawBar(
            canvas,
            cx - barW - 2,
            barW,
            g.inningsA!,
            topPad,
            chartH,
            colorA,
          );
        }
        if (g.inningsB != null) {
          _drawBar(
            canvas,
            cx + 2,
            barW,
            g.inningsB!,
            topPad,
            chartH,
            colorB,
          );
        }
      } else if (g.inningsA != null) {
        _drawBar(canvas, cx - barW / 2, barW, g.inningsA!, topPad, chartH, colorA);
      }

      if (i % 2 == 1 || groups.length <= 10) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${g.overNumber}',
            style: TextStyle(fontSize: 9, color: cf.textSecondary),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, topPad + chartH + 6));
      }
    }
  }

  void _drawBar(
    Canvas canvas,
    double x,
    double width,
    ManhattanOverDetail detail,
    double topPad,
    double chartH,
    Color color,
  ) {
    final h = (detail.runs / maxY) * chartH;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, topPad + chartH - h, width, h),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = color);

    if (detail.wickets > 0) {
      final marker = detail.wickets == 1
          ? 'W'
          : detail.wickets == 2
              ? '2W'
              : '${detail.wickets}W';
      final tp = TextPainter(
        text: TextSpan(
          text: marker,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: cf.textPrimary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x + width / 2 - tp.width / 2, topPad + chartH - h - tp.height - 2),
      );
    }
  }

  void _drawAvgLine(
    Canvas canvas,
    double leftPad,
    double chartW,
    double topPad,
    double chartH,
    double avgRr,
    Color color,
  ) {
    final y = topPad + chartH - (avgRr.clamp(0, maxY.toDouble()) / maxY) * chartH;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.5;
    _drawDashedLine(
      canvas,
      Offset(leftPad, y),
      Offset(leftPad + chartW, y),
      paint,
    );
  }

  void _drawYLabel(Canvas canvas, int value, double leftPad, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$value',
        style: TextStyle(fontSize: 9, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
  }

  List<int> _yTicks(int max) {
    final step = max <= 8 ? 4 : max <= 20 ? 4 : 5;
    final ticks = <int>[];
    for (var v = 0; v <= max; v += step) {
      ticks.add(v);
    }
    if (ticks.last != max) ticks.add(max);
    return ticks;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    var drawn = 0.0;
    while (drawn < dist) {
      final x1 = start.dx + ux * drawn;
      final y1 = start.dy + uy * drawn;
      final x2 = start.dx + ux * (drawn + dash).clamp(0, dist);
      final y2 = start.dy + uy * (drawn + dash).clamp(0, dist);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      drawn += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _ManhattanChartPainter oldDelegate) => true;
}

class _MomentumInsights extends StatelessWidget {
  const _MomentumInsights({
    required this.insights,
    required this.cf,
    this.isTestMatch = false,
  });

  final ManhattanMomentumInsights insights;
  final CfColors cf;
  final bool isTestMatch;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Highest Scoring Over', insights.highestScoringOverLabel),
      ('Most Economical Over', insights.mostEconomicalOverLabel),
      ('Best Bowling Phase', insights.bestBowlingPhaseLabel),
      if (!isTestMatch) ('Powerplay RR', insights.powerplayRunRateLabel),
      if (!isTestMatch) ('Death Overs RR', insights.deathOversRunRateLabel),
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
      'This graph shows runs scored over-by-over.',
      'Tap any bar for detailed over analysis.',
      'Wicket markers indicate wickets lost in that over.',
      'Dashed lines represent average run rates.',
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
