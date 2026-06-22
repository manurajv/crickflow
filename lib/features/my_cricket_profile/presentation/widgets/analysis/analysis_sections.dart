import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/player_model.dart';
import '../../../../../domain/services/player_analysis_models.dart';
import '../../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../matches/presentation/widgets/insights/insights_chart_widgets.dart';
import '../../../../wagon_wheel/presentation/widgets/wagon_wheel_embedded_section.dart';
import '../../../../../domain/wagon_wheel/wagon_wheel_filter.dart';

class PlayerSummarySection extends StatelessWidget {
  const PlayerSummarySection({
    super.key,
    required this.summary,
    required this.cf,
  });

  final PlayerSummaryAnalysis summary;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return AnalysisCollapsibleSection(
      title: 'Player Summary',
      subtitle: 'Archetype, form & career trend',
      initiallyExpanded: true,
      child: Column(
        children: [
          _SummaryGrid(
            cf: cf,
            items: [
              _SummaryItem(
                label: 'Batting Cluster',
                value: summary.battingCluster != null
                    ? _battingClusterLabel(summary.battingCluster!)
                    : '—',
              ),
              _SummaryItem(
                label: 'Bowling Cluster',
                value: summary.bowlingCluster != null
                    ? _bowlingClusterLabel(summary.bowlingCluster!)
                    : '—',
              ),
              _SummaryItem(
                label: 'Primary Strength',
                value: summary.primaryStrength.isEmpty
                    ? '—'
                    : summary.primaryStrength,
                highlight: true,
              ),
              _SummaryItem(
                label: 'Secondary Strength',
                value: summary.secondaryStrength.isEmpty
                    ? '—'
                    : summary.secondaryStrength,
              ),
              _SummaryItem(
                label: 'Current Form',
                value: summary.formLabel,
                highlight: summary.currentForm == FormTrend.excellent ||
                    summary.currentForm == FormTrend.good,
              ),
              _SummaryItem(
                label: 'Career Trend',
                value: summary.trendLabel,
                highlight: summary.careerTrend == CareerTrend.improving,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _battingClusterLabel(BattingClusterType type) => switch (type) {
      BattingClusterType.steadyBatter => 'Steady Batter',
      BattingClusterType.classicist => 'Classicist',
      BattingClusterType.accumulator => 'Accumulator',
      BattingClusterType.hardHitter => 'Hard Hitter',
      BattingClusterType.destroyer => 'Destroyer',
    };

String _bowlingClusterLabel(BowlingClusterType type) => switch (type) {
      BowlingClusterType.aspirant => 'Aspirant',
      BowlingClusterType.wildcard => 'Wildcard',
      BowlingClusterType.economist => 'Economist',
      BowlingClusterType.spearhead => 'Spearhead',
    };

class BattingAnalysisSection extends StatelessWidget {
  const BattingAnalysisSection({
    super.key,
    required this.snapshot,
    required this.cf,
  });

  final PlayerAdvancedAnalysisSnapshot snapshot;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return AnalysisCollapsibleSection(
      title: 'Batting Analysis',
      subtitle: 'Run patterns, zones, match-ups & phases',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubHeading('Run Distribution', cf),
          _RunDistributionChart(distribution: snapshot.runDistribution, cf: cf),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Scoring Areas', cf),
          if (snapshot.scoringZones.hasData) ...[
            _HighlightRow(
              cf: cf,
              favorite: snapshot.scoringZones.favoriteZone,
              weakest: snapshot.scoringZones.weakestZone,
            ),
            InsightsHorizontalBars(
              items: snapshot.scoringZones.zones.entries
                  .map(
                    (e) => (
                      label: e.key,
                      value: e.value.toDouble(),
                      trailing:
                          '${snapshot.scoringZones.zonePct(e.key).toStringAsFixed(0)}%',
                      color: cf.accent,
                      highlight: e.key == snapshot.scoringZones.favoriteZone,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value)),
            ),
          ] else
            const InsightsEmptyHint(
              message: 'More matches required for analysis.',
            ),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Vs Bowling Types', cf),
          _MetricCards(buckets: snapshot.battingVsBowlingType, cf: cf, batting: true),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Phase Analysis', cf),
          _MetricCards(buckets: snapshot.battingPhases, cf: cf, batting: true),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Dismissals', cf),
          _DismissalCharts(
            breakdown: snapshot.battingDismissals,
            cf: cf,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Chase vs Defend', cf),
          Row(
            children: [
              Expanded(
                child: _ChaseDefendCard(
                  bucket: snapshot.defendBatting,
                  cf: cf,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _ChaseDefendCard(
                  bucket: snapshot.chaseBatting,
                  cf: cf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BowlingAnalysisSection extends StatelessWidget {
  const BowlingAnalysisSection({
    super.key,
    required this.snapshot,
    required this.cf,
  });

  final PlayerAdvancedAnalysisSnapshot snapshot;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final hasBowling = snapshot.bowlingVsHand.isNotEmpty ||
        snapshot.wicketsByPosition.isNotEmpty ||
        snapshot.bowlingDismissals.hasData;

    return AnalysisCollapsibleSection(
      title: 'Bowling Analysis',
      subtitle: 'Wickets, phases & batter match-ups',
      child: hasBowling
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SubHeading('Wicket Distribution', cf),
                _DismissalCharts(
                  breakdown: snapshot.bowlingDismissals,
                  cf: cf,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                _SubHeading('Vs Batter Hand', cf),
                _MetricCards(
                  buckets: snapshot.bowlingVsHand,
                  cf: cf,
                  batting: false,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                _SubHeading('Wickets by Batting Position', cf),
                InsightsHorizontalBars(
                  items: snapshot.wicketsByPosition
                      .map(
                        (b) => (
                          label: b.label,
                          value: b.wickets.toDouble(),
                          trailing: '${b.wickets} wkts',
                          color: cf.accent,
                          highlight: false,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                _SubHeading('Phase Analysis', cf),
                _MetricCards(
                  buckets: snapshot.bowlingPhases,
                  cf: cf,
                  batting: false,
                ),
              ],
            )
          : const InsightsEmptyHint(
              message: 'More matches required for analysis.',
            ),
    );
  }
}

class FieldingAnalysisSection extends StatelessWidget {
  const FieldingAnalysisSection({
    super.key,
    required this.fielding,
    required this.cf,
  });

  final FieldingAnalysis fielding;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return AnalysisCollapsibleSection(
      title: 'Fielding Analysis',
      subtitle: 'Catches, run outs & safe hands',
      child: fielding.hasData
          ? Column(
              children: [
                InsightsHorizontalBars(
                  items: [
                    (
                      label: 'Catches',
                      value: fielding.catches.toDouble(),
                      trailing: '${fielding.catches}',
                      color: cf.accent,
                      highlight: false,
                    ),
                    (
                      label: 'Run Outs',
                      value: fielding.runOuts.toDouble(),
                      trailing: '${fielding.runOuts}',
                      color: cf.accent,
                      highlight: false,
                    ),
                    (
                      label: 'Direct Hits',
                      value: fielding.directHits.toDouble(),
                      trailing: '${fielding.directHits}',
                      color: cf.accent,
                      highlight: false,
                    ),
                    (
                      label: 'Stumpings',
                      value: fielding.stumpings.toDouble(),
                      trailing: '${fielding.stumpings}',
                      color: cf.accent,
                      highlight: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _StatRow(
                  cf: cf,
                  label: 'Catch Success',
                  value: '${fielding.catchSuccessPct.toStringAsFixed(0)}%',
                ),
                _StatRow(
                  cf: cf,
                  label: 'Run Out Conversion',
                  value: '${fielding.runOutConversionPct.toStringAsFixed(0)}%',
                ),
                _StatRow(
                  cf: cf,
                  label: 'Safe Hands Rating',
                  value: '${fielding.safeHandsRating.toStringAsFixed(1)} / 5',
                ),
              ],
            )
          : const InsightsEmptyHint(
              message: 'More matches required for analysis.',
            ),
    );
  }
}

class CaptaincyAnalysisSection extends StatelessWidget {
  const CaptaincyAnalysisSection({
    super.key,
    required this.captaincy,
    required this.cf,
  });

  final CaptainStatsSnapshot captaincy;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return AnalysisCollapsibleSection(
      title: 'Captaincy Analysis',
      subtitle: '${captaincy.matchesAsCaptain} matches as captain',
      child: Column(
        children: [
          _SummaryGrid(
            cf: cf,
            items: [
              _SummaryItem(label: 'Matches', value: '${captaincy.matchesAsCaptain}'),
              _SummaryItem(label: 'Wins', value: '${captaincy.wins}'),
              _SummaryItem(label: 'Losses', value: '${captaincy.losses}'),
              _SummaryItem(
                label: 'Win %',
                value: '${captaincy.winPct.toStringAsFixed(0)}%',
                highlight: captaincy.winPct >= 50,
              ),
              _SummaryItem(
                label: 'Toss %',
                value: '${captaincy.tossPct.toStringAsFixed(0)}%',
              ),
              _SummaryItem(
                label: 'Avg Team Score',
                value: captaincy.avgTeamScore.toStringAsFixed(0),
              ),
              _SummaryItem(
                label: 'Successful Chases',
                value:
                    '${captaincy.successfulChases}/${captaincy.chaseAttempts}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OpponentAnalysisSection extends StatelessWidget {
  const OpponentAnalysisSection({
    super.key,
    required this.snapshot,
    required this.cf,
  });

  final PlayerAdvancedAnalysisSnapshot snapshot;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (snapshot.topOpponents.isEmpty) {
      return AnalysisCollapsibleSection(
        title: 'Opponent Analysis',
        child: const InsightsEmptyHint(
          message: 'More matches required for analysis.',
        ),
      );
    }

    return AnalysisCollapsibleSection(
      title: 'Opponent Analysis',
      subtitle: 'Best & worst match-ups',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.bestOpponents.isNotEmpty) ...[
            _SubHeading('Best Against', cf),
            ...snapshot.bestOpponents.map(
              (b) => _OpponentTile(bucket: b, cf: cf, positive: true),
            ),
          ],
          if (snapshot.worstOpponents.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceSm),
            _SubHeading('Worst Against', cf),
            ...snapshot.worstOpponents.map(
              (b) => _OpponentTile(bucket: b, cf: cf, positive: false),
            ),
          ],
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Top Opponents', cf),
          _MetricCards(
            buckets: snapshot.topOpponents,
            cf: cf,
            batting: true,
          ),
        ],
      ),
    );
  }
}

class MatchSituationSection extends StatelessWidget {
  const MatchSituationSection({
    super.key,
    required this.situations,
    required this.cf,
  });

  final List<AnalysisMetricBucket> situations;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return AnalysisCollapsibleSection(
      title: 'Match Situation Analysis',
      subtitle: 'Performance under pressure',
      child: situations.isEmpty
          ? const InsightsEmptyHint(
              message: 'More matches required for analysis.',
            )
          : _MetricCards(buckets: situations, cf: cf, batting: true),
    );
  }
}

class ProgressionAnalysisSection extends StatelessWidget {
  const ProgressionAnalysisSection({
    super.key,
    required this.snapshot,
    required this.cf,
  });

  final PlayerAdvancedAnalysisSnapshot snapshot;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return AnalysisCollapsibleSection(
      title: 'Progression Analysis',
      subtitle: 'Form, consistency & career growth',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubHeading('Form Windows', cf),
          ...snapshot.formWindows.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FormWindowTile(window: w, cf: cf),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Form Trend', cf),
          if (snapshot.formSeries.length >= 2)
            InsightsLineChart(
              series: [
                InsightsLineSeries(
                  label: 'Runs',
                  color: cf.accent,
                  points: [
                    for (var i = 0; i < snapshot.formSeries.length; i++)
                      Offset(
                        i.toDouble(),
                        snapshot.formSeries[i].runs,
                      ),
                  ],
                ),
                InsightsLineSeries(
                  label: 'Wickets',
                  color: cf.success,
                  points: [
                    for (var i = 0; i < snapshot.formSeries.length; i++)
                      Offset(
                        i.toDouble(),
                        snapshot.formSeries[i].wickets * 20,
                      ),
                  ],
                ),
              ],
            )
          else
            const InsightsEmptyHint(message: 'More matches required for analysis.'),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Consistency', cf),
          if (snapshot.consistency.hasData)
            _SummaryGrid(
              cf: cf,
              items: [
                _SummaryItem(
                  label: 'Average Score',
                  value: snapshot.consistency.average.toStringAsFixed(1),
                ),
                _SummaryItem(
                  label: 'Median Score',
                  value: snapshot.consistency.median.toStringAsFixed(0),
                ),
                _SummaryItem(
                  label: '30+ Scores',
                  value: '${snapshot.consistency.thirtiesPlus}',
                ),
                _SummaryItem(
                  label: '50+ Scores',
                  value: '${snapshot.consistency.fiftiesPlus}',
                ),
                _SummaryItem(
                  label: '100+ Scores',
                  value: '${snapshot.consistency.hundredsPlus}',
                ),
                _SummaryItem(
                  label: 'Duck %',
                  value: '${snapshot.consistency.duckPct.toStringAsFixed(0)}%',
                ),
              ],
            )
          else
            const InsightsEmptyHint(message: 'More matches required for analysis.'),
          const SizedBox(height: AppDimens.spaceMd),
          _SubHeading('Career Progression', cf),
          if (snapshot.yearlyProgression.length >= 2)
            InsightsLineChart(
              series: [
                InsightsLineSeries(
                  label: 'Runs',
                  color: cf.accent,
                  points: [
                    for (var i = 0; i < snapshot.yearlyProgression.length; i++)
                      Offset(
                        i.toDouble(),
                        snapshot.yearlyProgression[i].runs.toDouble(),
                      ),
                  ],
                ),
                InsightsLineSeries(
                  label: 'Wickets',
                  color: cf.success,
                  points: [
                    for (var i = 0; i < snapshot.yearlyProgression.length; i++)
                      Offset(
                        i.toDouble(),
                        snapshot.yearlyProgression[i].wickets.toDouble() * 15,
                      ),
                  ],
                ),
              ],
            )
          else
            const InsightsEmptyHint(message: 'More matches required for analysis.'),
        ],
      ),
    );
  }
}

class HeatmapsSection extends StatelessWidget {
  const HeatmapsSection({
    super.key,
    required this.snapshot,
    required this.cf,
    this.player,
  });

  final PlayerAdvancedAnalysisSnapshot snapshot;
  final CfColors cf;
  final PlayerModel? player;

  @override
  Widget build(BuildContext context) {
    return AnalysisCollapsibleSection(
      title: 'Heatmaps & Visualizations',
      subtitle: 'Scoring zones & wagon wheel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.heatZones.isNotEmpty) ...[
            _SubHeading('Scoring Zone Heatmap', cf),
            InsightsHorizontalBars(
              items: snapshot.heatZones.entries
                  .map(
                    (e) => (
                      label: e.key,
                      value: e.value.toDouble(),
                      trailing: '${e.value} runs',
                      color: cf.accent,
                      highlight: e.key == snapshot.scoringZones.favoriteZone,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value)),
            ),
          ],
          if (snapshot.wicketHeatZones.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceMd),
            _SubHeading('Wicket Zones', cf),
            InsightsHorizontalBars(
              items: snapshot.wicketHeatZones.entries
                  .map(
                    (e) => (
                      label: e.key,
                      value: e.value.toDouble(),
                      trailing: '${e.value} wkts',
                      color: cf.error,
                      highlight: false,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value)),
            ),
          ],
          if (player != null) ...[
            const SizedBox(height: AppDimens.spaceMd),
            WagonWheelEmbeddedSection(
              title: 'Batting wagon wheel',
              fullViewTitle: '${player!.name} — batting',
              baseFilter: WagonWheelFilter(batterId: player!.id),
              batterBattingStyle: player!.battingStyle,
              batterCareerMode: true,
            ),
          ],
          if (snapshot.heatZones.isEmpty &&
              snapshot.wicketHeatZones.isEmpty &&
              player == null)
            const InsightsEmptyHint(
              message: 'More matches required for analysis.',
            ),
        ],
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class AnalysisCollapsibleSection extends StatelessWidget {
  const AnalysisCollapsibleSection({
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
  Widget build(BuildContext context) {
    return InsightsCollapsibleSection(
      title: title,
      subtitle: subtitle,
      initiallyExpanded: initiallyExpanded,
      child: child,
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text, this.cf);

  final String text;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cf.textPrimary,
            ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cf, required this.items});

  final CfColors cf;
  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceSm,
      children: items.map((item) {
        return Container(
          width: (MediaQuery.sizeOf(context).width - 48) / 2 - 4,
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          decoration: BoxDecoration(
            color: cf.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: item.highlight ? cf.accent.withValues(alpha: 0.4) : cf.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(fontSize: 11, color: cf.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: item.highlight ? cf.accent : cf.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RunDistributionChart extends StatelessWidget {
  const _RunDistributionChart({required this.distribution, required this.cf});

  final RunDistribution distribution;
  final CfColors cf;

  static const _colors = [
    Color(0xFF1565C0),
    Color(0xFF42A5F5),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFEF5350),
    Color(0xFF78909C),
  ];

  @override
  Widget build(BuildContext context) {
    if (!distribution.hasData) {
      return const InsightsEmptyHint(
        message: 'More matches required for analysis.',
      );
    }

    final items = [
      ('Singles', distribution.singles, _colors[0]),
      ('Doubles', distribution.doubles, _colors[1]),
      ('Triples', distribution.triples, _colors[2]),
      ('Fours', distribution.fours, _colors[3]),
      ('Sixes', distribution.sixes, _colors[4]),
      ('Dots', distribution.dots, _colors[5]),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightsPieChart(
          slices: [
            for (final s in items)
              if (s.$2 > 0) (label: s.$1, value: s.$2.toDouble(), color: s.$3),
          ],
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: InsightsLegend(
            items: [
              for (final s in items)
                if (s.$2 > 0)
                  (
                    color: s.$3,
                    label: s.$1,
                    value: '${distribution.pct(s.$2).toStringAsFixed(0)}%',
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DismissalCharts extends StatelessWidget {
  const _DismissalCharts({required this.breakdown, required this.cf});

  final DismissalBreakdown breakdown;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (!breakdown.hasData) {
      return const InsightsEmptyHint(
        message: 'More matches required for analysis.',
      );
    }

    final palette = [
      cf.accent,
      cf.success,
      const Color(0xFF7E57C2),
      const Color(0xFF26A69A),
      cf.error,
      cf.statusUpcoming,
    ];

    final entries = breakdown.counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightsPieChart(
          slices: [
            for (var i = 0; i < entries.length; i++)
              (
                label: entries[i].key,
                value: entries[i].value.toDouble(),
                color: palette[i % palette.length],
              ),
          ],
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: InsightsLegend(
            items: [
              for (var i = 0; i < entries.length; i++)
                (
                  color: palette[i % palette.length],
                  label: entries[i].key,
                  value: '${breakdown.pct(entries[i].key).toStringAsFixed(0)}%',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCards extends StatelessWidget {
  const _MetricCards({
    required this.buckets,
    required this.cf,
    required this.batting,
  });

  final List<AnalysisMetricBucket> buckets;
  final CfColors cf;
  final bool batting;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const InsightsEmptyHint(
        message: 'More matches required for analysis.',
      );
    }

    return Column(
      children: buckets.map((b) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          decoration: BoxDecoration(
            color: cf.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cf.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                batting
                    ? 'Runs ${b.runs} · Avg ${b.average.toStringAsFixed(1)} · SR ${b.strikeRate.toStringAsFixed(0)} · Bdry ${b.boundaryPct.toStringAsFixed(0)}%'
                    : 'Wkts ${b.wickets} · Econ ${b.economy.toStringAsFixed(1)} · Avg ${b.bowlingAverage.toStringAsFixed(1)} · Dots ${b.dotPct.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: cf.textSecondary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChaseDefendCard extends StatelessWidget {
  const _ChaseDefendCard({required this.bucket, required this.cf});

  final AnalysisMetricBucket bucket;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: cf.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bucket.label,
            style: TextStyle(fontWeight: FontWeight.w700, color: cf.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Avg ${bucket.average.toStringAsFixed(1)}',
            style: TextStyle(color: cf.accent, fontWeight: FontWeight.w700),
          ),
          Text(
            'SR ${bucket.strikeRate.toStringAsFixed(0)} · ${bucket.innings} inn',
            style: TextStyle(fontSize: 12, color: cf.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.cf,
    required this.favorite,
    required this.weakest,
  });

  final CfColors cf;
  final String favorite;
  final String weakest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Favorite: $favorite',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cf.success,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Weakest: $weakest',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cf.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  const _OpponentTile({
    required this.bucket,
    required this.cf,
    required this.positive,
  });

  final AnalysisMetricBucket bucket;
  final CfColors cf;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cf.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: positive
              ? cf.success.withValues(alpha: 0.35)
              : cf.error.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '${bucket.label} — Avg ${bucket.average.toStringAsFixed(0)} · SR ${bucket.strikeRate.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cf.textPrimary,
        ),
      ),
    );
  }
}

class _FormWindowTile extends StatelessWidget {
  const _FormWindowTile({required this.window, required this.cf});

  final FormWindowStats window;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: cf.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cf.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              window.label,
              style: TextStyle(fontWeight: FontWeight.w700, color: cf.textPrimary),
            ),
          ),
          Text(
            '${window.runs} runs · ${window.wickets} wkts · SR ${window.strikeRate.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, color: cf.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.cf,
    required this.label,
    required this.value,
  });

  final CfColors cf;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: cf.textSecondary)),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: cf.textPrimary),
          ),
        ],
      ),
    );
  }
}
