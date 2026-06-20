import 'package:flutter/material.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/display/match_revision_display.dart';
import '../../../../../domain/services/match_analytics_models.dart';
import '../../../../../shared/widgets/stat_grid.dart';
import 'insights_chart_widgets.dart';

class InsightsMatchSummarySection extends StatelessWidget {
  const InsightsMatchSummarySection({
    super.key,
    required this.summary,
    this.dlsInfo,
    this.penalties = const [],
  });

  final MatchSummaryAnalytics summary;
  final DlsSummaryInfo? dlsInfo;
  final List<PenaltyAdjustmentEntry> penalties;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dlsInfo != null) ...[
          _DlsBadge(info: dlsInfo!),
          const SizedBox(height: AppDimens.spaceSm),
        ],
        if (penalties.isNotEmpty) ...[
          _PenaltyBanner(penalties: penalties),
          const SizedBox(height: AppDimens.spaceSm),
        ],
        StatGrid(
          cells: [
            StatCellData(value: summary.topBatterLabel, label: 'Top Batter'),
            StatCellData(value: summary.bestBowlerLabel, label: 'Best Bowler'),
            StatCellData(
              value: summary.highestPartnershipLabel,
              label: 'Highest Partnership',
            ),
            StatCellData(
              value: '${summary.boundaryPercent.toStringAsFixed(0)}%',
              label: 'Boundary %',
            ),
            StatCellData(
              value: '${summary.dotBallPercent.toStringAsFixed(0)}%',
              label: 'Dot Ball %',
            ),
            StatCellData(value: '${summary.extras}', label: 'Extras'),
            StatCellData(
              value: summary.mostExpensiveOverLabel,
              label: 'Most Expensive Over',
            ),
            StatCellData(
              value: summary.bestOverLabel,
              label: 'Best Over',
            ),
          ],
        ),
        if (dlsInfo != null) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _DlsDetails(info: dlsInfo!, cf: cf),
        ],
      ],
    );
  }
}

class _DlsBadge extends StatelessWidget {
  const _DlsBadge({required this.info});

  final DlsSummaryInfo info;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cf.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cf.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: cf.info),
          const SizedBox(width: 8),
          Text(
            'DLS Revised Target',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cf.info,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DlsDetails extends StatelessWidget {
  const _DlsDetails({required this.info, required this.cf});

  final DlsSummaryInfo info;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppDimens.cardPadding,
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.originalTarget != null)
            _row('Original Target', '${info.originalTarget}'),
          if (info.revisedTarget != null)
            _row('Revised Target', '${info.revisedTarget}'),
          if (info.originalOvers != null && info.revisedOvers != null)
            _row(
              'Overs Reduced',
              '${info.originalOvers} → ${info.revisedOvers}',
            ),
          if (info.appliedAtLabel != null)
            _row('DLS Applied At', info.appliedAtLabel!),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: cf.textSecondary, fontSize: 12)),
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: cf.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PenaltyBanner extends StatelessWidget {
  const _PenaltyBanner({required this.penalties});

  final List<PenaltyAdjustmentEntry> penalties;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: AppDimens.cardPadding,
      decoration: BoxDecoration(
        color: cf.statusUpcoming.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: penalties.map((entry) {
          final runs = entry.runs;
          final reason = entry.reason;
          final source = entry.source;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Penalty Runs Awarded: ${runs > 0 ? '+' : ''}$runs',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cf.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  source,
                  style: TextStyle(color: cf.textSecondary, fontSize: 12),
                ),
                if (reason.isNotEmpty)
                  Text(
                    'Reason: $reason',
                    style: TextStyle(color: cf.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class InsightsScoringAreasSection extends StatelessWidget {
  const InsightsScoringAreasSection({
    super.key,
    required this.legSidePercent,
    required this.offSidePercent,
    required this.straightPercent,
    required this.cf,
  });

  final double legSidePercent;
  final double offSidePercent;
  final double straightPercent;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final total = legSidePercent + offSidePercent + straightPercent;
    if (total <= 0) {
      return const InsightsEmptyHint(
        message: 'Scoring areas appear when wagon wheel data is recorded',
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightsPieChart(
          slices: [
            (label: 'Leg', value: legSidePercent, color: cf.accent),
            (label: 'Off', value: offSidePercent, color: cf.info),
            (label: 'Straight', value: straightPercent, color: cf.success),
          ],
        ),
        const SizedBox(width: AppDimens.spaceLg),
        Expanded(
          child: InsightsLegend(
            items: [
              (
                color: cf.accent,
                label: 'Leg Side',
                value: '${legSidePercent.toStringAsFixed(0)}%',
              ),
              (
                color: cf.info,
                label: 'Off Side',
                value: '${offSidePercent.toStringAsFixed(0)}%',
              ),
              (
                color: cf.success,
                label: 'Straight',
                value: '${straightPercent.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class InsightsPhaseSection extends StatelessWidget {
  const InsightsPhaseSection({super.key, required this.phases, required this.cf});

  final List<PhaseAnalytics> phases;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (phases.isEmpty) {
      return const InsightsEmptyHint(message: 'Phase analysis not available');
    }

    return Column(
      children: phases.map((phase) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: AppDimens.cardPadding,
          decoration: cfCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      phase.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${phase.runs}/${phase.wickets}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cf.scoreEmphasis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'RR ${phase.runRate.toStringAsFixed(2)}',
                    style: TextStyle(color: cf.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _metric('Boundaries', '${phase.boundaries}', cf),
                  _metric(
                    'Dot %',
                    '${phase.dotBallPercent.toStringAsFixed(0)}%',
                    cf,
                  ),
                  _metric(
                    'SR',
                    phase.strikeRate.toStringAsFixed(0),
                    cf,
                  ),
                  if (phase.label.contains('Middle'))
                    _metric(
                      'Rotation',
                      '${phase.strikeRotationPercent.toStringAsFixed(0)}%',
                      cf,
                    )
                  else
                    _metric(
                      'Boundary %',
                      '${phase.boundaryPercent.toStringAsFixed(0)}%',
                      cf,
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _metric(String label, String value, CfColors cf) {
    return Text(
      '$label $value',
      style: TextStyle(fontSize: 11, color: cf.textSecondary),
    );
  }
}

class InsightsBoundarySection extends StatelessWidget {
  const InsightsBoundarySection({
    super.key,
    required this.data,
    required this.cf,
  });

  final BoundaryAnalytics data;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatGrid(
          cells: [
            StatCellData(value: '${data.fours}', label: '4s'),
            StatCellData(value: '${data.sixes}', label: '6s'),
            StatCellData(value: '${data.boundaryRuns}', label: 'Boundary Runs'),
            StatCellData(
              value: '${data.boundaryPercent.toStringAsFixed(0)}%',
              label: 'Boundary %',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InsightsPieChart(
              slices: [
                (label: '4s', value: data.fours.toDouble(), color: cf.accent),
                (label: '6s', value: data.sixes.toDouble(), color: cf.success),
              ],
            ),
            const SizedBox(width: AppDimens.spaceLg),
            Expanded(
              child: InsightsLegend(
                items: [
                  (color: cf.accent, label: 'Fours', value: '${data.fours}'),
                  (color: cf.success, label: 'Sixes', value: '${data.sixes}'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class InsightsBowlingImpactSection extends StatelessWidget {
  const InsightsBowlingImpactSection({
    super.key,
    required this.bowlers,
    required this.cf,
  });

  final List<BowlingImpactAnalytics> bowlers;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (bowlers.isEmpty) {
      return const InsightsEmptyHint(message: 'No bowling data yet');
    }

    final top = bowlers.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsightsHorizontalBars(
          maxValue: top.first.impactScore,
          items: top
              .map(
                (b) => (
                  label: b.playerName,
                  value: b.impactScore,
                  trailing:
                      '${b.oversLabel} · ${b.wickets}/${b.runs} · Econ ${b.economy.toStringAsFixed(1)} · Dots ${b.dotBallPercent.toStringAsFixed(0)}%',
                  color: cf.accent,
                  highlight: false,
                ),
              )
              .toList(),
        ),
        if (bowlers.length > 5) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            '+ ${bowlers.length - 5} more bowlers',
            style: TextStyle(fontSize: 11, color: cf.textSecondary),
          ),
        ],
      ],
    );
  }
}

class InsightsExtrasSection extends StatelessWidget {
  const InsightsExtrasSection({super.key, required this.data, required this.cf});

  final ExtrasAnalytics data;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (data.total == 0) {
      return const InsightsEmptyHint(message: 'No extras recorded');
    }

    return Column(
      children: [
        StatGrid(
          cells: [
            StatCellData(value: '${data.total}', label: 'Extras'),
            StatCellData(value: '${data.wides}', label: 'Wide'),
            StatCellData(value: '${data.noBalls}', label: 'No Ball'),
            StatCellData(value: '${data.byes}', label: 'Bye'),
            StatCellData(value: '${data.legByes}', label: 'Leg Bye'),
            StatCellData(value: '${data.penalties}', label: 'Penalty'),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InsightsPieChart(
              slices: [
                if (data.wides > 0)
                  (label: 'Wide', value: data.wides.toDouble(), color: cf.accent),
                if (data.noBalls > 0)
                  (label: 'NB', value: data.noBalls.toDouble(), color: cf.info),
                if (data.byes > 0)
                  (label: 'Bye', value: data.byes.toDouble(), color: cf.success),
                if (data.legByes > 0)
                  (label: 'LB', value: data.legByes.toDouble(), color: cf.statusUpcoming),
                if (data.penalties > 0)
                  (label: 'Pen', value: data.penalties.toDouble(), color: cf.error),
              ],
            ),
            const SizedBox(width: AppDimens.spaceLg),
            Expanded(
              child: InsightsLegend(
                items: [
                  (color: cf.accent, label: 'Wide', value: '${data.percentOf(data.wides).toStringAsFixed(0)}%'),
                  (color: cf.info, label: 'No Ball', value: '${data.percentOf(data.noBalls).toStringAsFixed(0)}%'),
                  (color: cf.success, label: 'Bye', value: '${data.percentOf(data.byes).toStringAsFixed(0)}%'),
                  (color: cf.statusUpcoming, label: 'Leg Bye', value: '${data.percentOf(data.legByes).toStringAsFixed(0)}%'),
                  (color: cf.error, label: 'Penalty', value: '${data.percentOf(data.penalties).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class InsightsDotBallSection extends StatelessWidget {
  const InsightsDotBallSection({super.key, required this.data, required this.cf});

  final DotBallAnalytics data;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatGrid(
          cells: [
            StatCellData(value: '${data.dotBalls}', label: 'Dot Balls'),
            StatCellData(value: '${data.scoringBalls}', label: 'Scoring Balls'),
            StatCellData(
              value: '${data.dotBallPercent.toStringAsFixed(0)}%',
              label: 'Dot Ball %',
            ),
            StatCellData(
              value: '${data.boundaryBallPercent.toStringAsFixed(0)}%',
              label: 'Boundary Ball %',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InsightsPieChart(
              slices: [
                (label: 'Dots', value: data.dotBalls.toDouble(), color: cf.textMuted),
                (label: 'Scoring', value: data.scoringBalls.toDouble(), color: cf.accent),
              ],
            ),
            const SizedBox(width: AppDimens.spaceLg),
            Expanded(
              child: InsightsLegend(
                items: [
                  (color: cf.textMuted, label: 'Dot Balls', value: '${data.dotBalls}'),
                  (color: cf.accent, label: 'Scoring Balls', value: '${data.scoringBalls}'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
